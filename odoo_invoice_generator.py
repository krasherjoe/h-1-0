"""
Odoo請求書発行システム（REST APIを使用）
========================================
"""

import requests
from datetime import datetime
import json
import logging


class OdooAPI:
    """
    Odoo APIクライアント
    """

    def __init__(self, base_url: str, db: str, username: str, password: str):
        self.base_url = f"{base_url}/api/v13"
        self.db = db
        self.session = requests.Session()
        self.login()

    def login(self) -> bool:
        """
        Odoo APIに認証する

        戻り値:
            bool: 認証成功の場合はTrue、失敗の場合はFalse
        """
        url = f"{self.base_url}/login/db_{self.db}"
        data = {
            "jsonrpc": "2.0",
            "method": "call",
            "params": {
                "service": "object",
                "method": "service_login",
                "args": [self.db, username, password]
            }
        }

        response = self.session.post(url, json=data)
        if response.status_code == 200:
            result = response.json()
            self.session_id = result["result"]["session_id"]
            return True
        else:
            logging.error(f"ログイン失敗: {response.text}")
            return False

    def logout(self) -> bool:
        """
        Odoo APIからログアウトする

        戻り値:
            bool: ログアウト成功の場合はTrue、失敗の場合はFalse
        """
        url = f"{self.base_url}/login/logout"
        data = {
            "jsonrpc": "2.0",
            "method": "call",
            "params": {
                "service": "object",
                "method": "service_logout",
                "args": [self.session_id]
            }
        }

        response = self.session.post(url, json=data)
        if response.status_code == 200:
            return True
        else:
            logging.error(f"ログアウト失敗: {response.text}")
            return False

    def get_partner(self, partner_id: int) -> dict | None:
        """
        顧客情報を取得する

        引数:
            partner_id (int): 取得する顧客のID

        戻り値:
            dict | None: 顧客データが見つかった場合、それ以外の場合はNone
        """
        url = f"{self.base_url}/res.partner/{partner_id}"
        headers = {
            "Authorization": f"Session {self.session_id}",
            "Content-Type": "application/json"
        }

        response = self.session.get(url, headers=headers)
        if response.status_code == 200:
            return response.json()["result"]
        else:
            logging.error(f"顧客情報取得失敗: {response.text}")
            return None

    def get_product(self, product_id: int) -> dict | None:
        """
        商品情報を取得する

        引数:
            product_id (int): 取得する商品のID

        戻り値:
            dict | None: 商品データが見つかった場合、それ以外の場合はNone
        """
        url = f"{self.base_url}/product.product/{product_id}"
        headers = {
            "Authorization": f"Session {self.session_id}",
            "Content-Type": "application/json"
        }

        response = self.session.get(url, headers=headers)
        if response.status_code == 200:
            return response.json()["result"]
        else:
            logging.error(f"商品情報取得失敗: {response.text}")
            return None

    def create_invoice(self, invoice_data: dict) -> dict | None:
        """
        新しい請求書を作成する

        引数:
            invoice_data (dict): 請求書データ

        戻り値:
            dict | None: 作成成功した場合の請求書データ、失敗の場合はNone
        """
        url = f"{self.base_url}/account.move"
        headers = {
            "Authorization": f"Session {self.session_id}",
            "Content-Type": "application/json"
        }

        response = self.session.post(url, headers=headers, json=invoice_data)
        if response.status_code == 200:
            return response.json()["result"]
        else:
            logging.error(f"請求書作成失敗: {response.text}")
            return None

    def get_invoices(self) -> list[dict]:
        """
        全ての請求書を取得する

        戻り値:
            list[dict]: 請求書リスト
        """
        url = f"{self.base_url}/account.move"
        headers = {
            "Authorization": f"Session {self.session_id}",
            "Content-Type": "application/json"
        }

        response = self.session.get(url, headers=headers)
        if response.status_code == 200:
            return response.json()["result"]
        else:
            logging.error(f"請求書取得失敗: {response.text}")
            return []


class InvoiceGenerator:
    """
    Odoo請求書生成器
    """

    def __init__(self, odoo_api: OdooAPI):
        self.odoo_api = odoo_api

    def generate_invoice(self, partner_id: int, product_id: int, quantity: int) -> dict | None:
        """
        指定された顧客と商品に対して新しい請求書を生成する

        引数:
            partner_id (int): 顧客ID
            product_id (int): 商品ID
            quantity (int): 売上数量

        戻り値:
            dict | None: 作成成功した場合の請求書データ、失敗の場合はNone
        """

        # 顧客情報を取得
        partner = self.odoo_api.get_partner(partner_id)
        if not partner:
            logging.error(f"顧客 {partner_id} が見つからない")
            return None

        # 商品情報を取得
        product = self.odoo_api.get_product(product_id)
        if not product:
            logging.error(f"商品 {product_id} が見つからない")
            return None

        # 合計金額を計算
        price_unit = product["lst_price"]
        subtotal = quantity * price_unit
        tax_rate = 0.08  # 8%の消費税（例、必要に応じて変更可能）
        tax_amount = subtotal * tax_rate / (1 + tax_rate)
        total = subtotal + tax_amount

        # 請求書データを作成
        invoice_data = {
            "journal_id": 1,  # デフォルトの勘定科目ID（必要に応じて変更可能）
            "partner_id": partner["id"],
            "date_invoice": datetime.now().strftime("%Y-%m-%d"),
            "move_type": "out_invoice",
            "state": "draft",  # 初期状態
            "name": f"{partner['name']} への請求書",
            "reference": f"INV-{datetime.now().strftime('%Y%m%d%H%M%S')}",
            "user_id": 1,  # デフォルトのユーザーID（必要に応じて変更可能）
            "company_id": 1,  # デフォルトの会社ID（必要に応じて変更可能）

            "invoice_line_ids": [
                {
                    "product_id": product["id"],
                    "name": f"{product['name']} x{quantity}",
                    "sequence": 10,
                    "type": "line",
                    "quantity": quantity,
                    "price_unit": price_unit,
                    "account_id": product.get("property_account_exp", {}).get("account_id"),
                    "analytic_index_ids": [],
                    "discount": 0.00
                }
            ],

            # 追加の行、割引などがあればここに追加可能
        }

        return self.odoo_api.create_invoice(invoice_data)

    def generate_invoices(self, partner_ids: list[int], product_ids: list[int]) -> dict:
        """
        複数の顧客と商品に対して請求書を生成する

        引数:
            partner_ids (list[int]): 顧客IDリスト
            product_ids (list[int]): 商品IDリスト

        戻り値:
            dict: 請求書データとエラーメッセージを含む辞書
        """

        # 結果辞書を初期化
        result = {"invoices": [], "errors": []}

        for partner_id in partner_ids:
            for product_id in product_ids:
                try:
                    invoice = self.generate_invoice(partner_id, product_id, 1)
                    if invoice:
                        result["invoices"].append(invoice)
                except Exception as e:
                    result["errors"].append(f"請求書生成失敗: {str(e)}")

        return result


# 実行例
if __name__ == "__main__":
    # Odoo API接続パラメータを設定
    base_url = "http://localhost:8069"
    db_name = "mydatabase"
    username = "admin"
    password = "password123"

    odoo_api = OdooAPI(base_url, db_name, username, password)

    if not odoo_api.login():
        print("Odoo APIへの認証失敗")
        exit(1)

    # インスタンスを作成
    invoice_generator = InvoiceGenerator(odoo_api)

    # 例1: 単一の請求書を生成
    partner_id = 2
    product_id = 3
    quantity = 5

    invoice = invoice_generator.generate_invoice(partner_id, product_id, quantity)
    if invoice:
        print("請求書作成成功:")
        print(json.dumps(invoice, indent=4))
    else:
        print(f"顧客 {partner_id} と商品 {product_id} に対する請求書作成失敗")

    # 例2: 複数の請求書を生成
    partner_ids = [1, 2, 3]
    product_ids = [101, 102, 103]

    result = invoice_generator.generate_invoices(partner_ids, product_ids)
    print("\n請求書生成結果:")
    print(f"作成された請求書: {len(result['invoices'])}")
    print(f"エラー: {len(result['errors'])}")

    # 請求書を表示
    for i, invoice in enumerate(result["invoices"]):
        print(f"\n請求書 {i+1}:")
        print(json.dumps(invoice, indent=4))

    # エラーを表示
    if result["errors"]:
        print("\nエラーログ:")
        for error in result["errors"]:
            print(error)

    # Odoo APIからログアウト
    odoo_api.logout()
