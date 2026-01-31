# api/odoo_sync.py
"""
Odoo連携モジュール
REST API が受け取ったドキュメントを Odoo に同期
"""

import requests
import logging
from typing import Dict, List, Optional
from datetime import datetime
import json

logger = logging.getLogger(__name__)

class OdooClient:
    """Odoo XML-RPC クライアント"""
    
    def __init__(self, odoo_url: str, db: str, username: str, password: str):
        self.odoo_url = odoo_url
        self.db = db
        self.username = username
        self.password = password
        self.uid = None
        self.authenticate()
    
    def authenticate(self):
        """Odoo 認証"""
        try:
            import xmlrpc.client
            common = xmlrpc.client.ServerProxy(f'{self.odoo_url}/xmlrpc/2/common')
            self.uid = common.authenticate(self.db, self.username, self.password, {})
            logger.info(f"Odoo authenticated: uid={self.uid}")
        except Exception as e:
            logger.error(f"Odoo authentication failed: {str(e)}")
            raise
    
    def create_customer(self, name: str, address: str = "", phone: str = "", email: str = "") -> int:
        """顧客を Odoo に作成"""
        try:
            import xmlrpc.client
            models = xmlrpc.client.ServerProxy(f'{self.odoo_url}/xmlrpc/2/object')
            
            partner_data = {
                'name': name,
                'street': address,
                'phone': phone,
                'email': email,
                'customer_rank': 1,
            }
            
            partner_id = models.execute_kw(
                self.db, self.uid, self.password,
                'res.partner', 'create', [partner_data]
            )
            
            logger.info(f"Created Odoo customer: {partner_id}")
            return partner_id
        
        except Exception as e:
            logger.error(f"Error creating customer: {str(e)}")
            return 0
    
    def create_quotation(self, customer_id: int, items: List[Dict], 
                        payment_due_date: str, notes: str = "") -> int:
        """見積を Odoo に作成"""
        try:
            import xmlrpc.client
            models = xmlrpc.client.ServerProxy(f'{self.odoo_url}/xmlrpc/2/object')
            
            # 見積ラインの準備
            order_lines = []
            for item in items:
                # 商品をOdooから検索（簡略版）
                product_search = models.execute_kw(
                    self.db, self.uid, self.password,
                    'product.product', 'search',
                    [[('name', '=', item['product_name'])]]
                )
                
                product_id = product_search[0] if product_search else 1
                
                line_data = (0, 0, {
                    'product_id': product_id,
                    'product_qty': item['quantity'],
                    'price_unit': item['unit_price'],
                })
                order_lines.append(line_data)
            
            # 見積作成
            quotation_data = {
                'partner_id': customer_id,
                'order_line': order_lines,
                'date_order': datetime.now().isoformat(),
                'payment_term_id': self._get_payment_term_id(payment_due_date),
                'note': notes,
            }
            
            quotation_id = models.execute_kw(
                self.db, self.uid, self.password,
                'sale.order', 'create', [quotation_data]
            )
            
            logger.info(f"Created Odoo quotation: {quotation_id}")
            return quotation_id
        
        except Exception as e:
            logger.error(f"Error creating quotation: {str(e)}")
            return 0
    
    def create_invoice(self, customer_id: int, items: List[Dict], 
                      payment_due_date: str, notes: str = "") -> int:
        """請求書を Odoo に作成"""
        try:
            import xmlrpc.client
            models = xmlrpc.client.ServerProxy(f'{self.odoo_url}/xmlrpc/2/object')
            
            invoice_lines = []
            for item in items:
                product_search = models.execute_kw(
                    self.db, self.uid, self.password,
                    'product.product', 'search',
                    [[('name', '=', item['product_name'])]]
                )
                
                product_id = product_search[0] if product_search else 1
                
                line_data = (0, 0, {
                    'product_id': product_id,
                    'quantity': item['quantity'],
                    'price_unit': item['unit_price'],
                })
                invoice_lines.append(line_data)
            
            invoice_data = {
                'partner_id': customer_id,
                'invoice_line_ids': invoice_lines,
                'invoice_date': datetime.now().date().isoformat(),
                'invoice_date_due': payment_due_date,
                'note': notes,
            }
            
            invoice_id = models.execute_kw(
                self.db, self.uid, self.password,
                'account.move', 'create', [invoice_data]
            )
            
            logger.info(f"Created Odoo invoice: {invoice_id}")
            return invoice_id
        
        except Exception as e:
            logger.error(f"Error creating invoice: {str(e)}")
            return 0
    
    def record_payment(self, invoice_id: int, amount: float, payment_date: str) -> int:
        """支払いを記録"""
        try:
            import xmlrpc.client
            models = xmlrpc.client.ServerProxy(f'{self.odoo_url}/xmlrpc/2/object')
            
            payment_data = {
                'move_id': invoice_id,
                'amount': amount,
                'payment_date': payment_date,
            }
            
            payment_id = models.execute_kw(
                self.db, self.uid, self.password,
                'account.payment', 'create', [payment_data]
            )
            
            logger.info(f"Recorded payment: {payment_id}")
            return payment_id
        
        except Exception as e:
            logger.error(f"Error recording payment: {str(e)}")
            return 0
    
    def get_customer_by_email(self, email: str) -> Optional[int]:
        """メールアドレスで顧客を検索"""
        try:
            import xmlrpc.client
            models = xmlrpc.client.ServerProxy(f'{self.odoo_url}/xmlrpc/2/object')
            
            result = models.execute_kw(
                self.db, self.uid, self.password,
                'res.partner', 'search',
                [[('email', '=', email)]]
            )
            
            return result[0] if result else None
        
        except Exception as e:
            logger.error(f"Error searching customer: {str(e)}")
            return None
    
    def _get_payment_term_id(self, due_date: str) -> int:
        """支払い条件を Odoo から取得"""
        try:
            import xmlrpc.client
            models = xmlrpc.client.ServerProxy(f'{self.odoo_url}/xmlrpc/2/object')
            
            # 簡略版：「30日」の支払い条件 ID を取得
            result = models.execute_kw(
                self.db, self.uid, self.password,
                'account.payment.term', 'search',
                [[('name', 'like', '30')]]
            )
            
            return result[0] if result else 1
        
        except Exception as e:
            logger.warning(f"Could not get payment term: {str(e)}")
            return 1


class SyncService:
    """REST API と Odoo の同期サービス"""
    
    def __init__(self, odoo_client: OdooClient):
        self.odoo = odoo_client
    
    def sync_document(self, db_session, document_entity) -> Dict:
        """ドキュメントを Odoo に同期"""
        
        # 顧客情報を取得
        customer = db_session.query(Customer).filter(
            Customer.id == document_entity.customer_id
        ).first()
        
        if not customer:
            return {"status": "error", "message": "Customer not found"}
        
        # Odoo 顧客 ID を確認・作成
        odoo_customer_id = customer.odoo_customer_id
        if not odoo_customer_id:
            odoo_customer_id = self.odoo.create_customer(
                name=customer.name,
                address=customer.address or "",
                phone=customer.phone or "",
                email=customer.email or ""
            )
            customer.odoo_customer_id = odoo_customer_id
            db_session.commit()
        
        if not odoo_customer_id:
            return {"status": "error", "message": "Could not create/find Odoo customer"}
        
        # ドキュメントタイプ別処理
        items = json.loads(document_entity.items)
        
        try:
            if document_entity.doc_type == "quotation":
                odoo_id = self.odoo.create_quotation(
                    customer_id=odoo_customer_id,
                    items=items,
                    payment_due_date=self._format_date(document_entity.payment_due_date),
                    notes=document_entity.notes or ""
                )
                
            elif document_entity.doc_type == "invoice":
                odoo_id = self.odoo.create_invoice(
                    customer_id=odoo_customer_id,
                    items=items,
                    payment_due_date=self._format_date(document_entity.payment_due_date),
                    notes=document_entity.notes or ""
                )
            
            else:
                odoo_id = 0
            
            if odoo_id:
                document_entity.odoo_id = odoo_id
                return {"status": "success", "odoo_id": odoo_id}
            else:
                return {"status": "error", "message": "Failed to create Odoo document"}
        
        except Exception as e:
            logger.error(f"Sync error: {str(e)}")
            return {"status": "error", "message": str(e)}
    
    @staticmethod
    def _format_date(timestamp: int) -> str:
        """タイムスタンプを ISO 形式に変換"""
        from datetime import datetime
        return datetime.fromtimestamp(timestamp / 1000).isoformat()


# FastAPI メインに統合される部分

from fastapi import FastAPI, Depends
from sqlalchemy.orm import Session

app = FastAPI()

# グローバル Odoo クライアント
odoo_client = OdooClient(
    odoo_url=os.getenv("ODOO_URL", "http://localhost:8069"),
    db="odoo",
    username=os.getenv("ODOO_USER", "admin"),
    password=os.getenv("ODOO_PASSWORD", "admin")
)

sync_service = SyncService(odoo_client)

@app.post("/api/v1/sync")
async def sync_documents(request: SyncRequest, db: Session = Depends(get_db)):
    """ドキュメント同期エンドポイント"""
    
    synced_count = 0
    new_documents = []
    
    for doc in request.documents:
        # ドキュメント作成（DB）
        db_doc = Document(...)
        db.add(db_doc)
        db.commit()
        
        # Odoo に同期
        result = sync_service.sync_document(db, db_doc)
        
        if result["status"] == "success":
            synced_count += 1
            new_documents.append({
                "local_id": db_doc.id,
                "odoo_id": result.get("odoo_id"),
                "doc_type": db_doc.doc_type
            })
    
    return SyncResponse(
        status="success",
        message=f"Synced {synced_count} documents",
        synced_documents=synced_count,
        new_documents=new_documents
    )
