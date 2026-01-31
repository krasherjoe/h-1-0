"""
Mobile Sync API - Odoo連携
見積/納品/請求/領収書のモバイル同期エンドポイント
"""

from fastapi import FastAPI, HTTPException, Depends, Header, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from datetime import datetime, timedelta
from typing import Optional, List
import sqlalchemy as sa
from sqlalchemy import create_engine, Column, Integer, String, DateTime, JSON, Numeric, Boolean, ForeignKey
from sqlalchemy.orm import sessionmaker, declarative_base, Session
from sqlalchemy.ext.declarative import declarative_base
import os
import json
import requests
from dateutil.relativedelta import relativedelta
import logging

# ========== 設定 ==========
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://odoo:odoo_secure_password@localhost:5432/odoo")
ODOO_URL = os.getenv("ODOO_URL", "http://localhost:8069")
ODOO_USER = os.getenv("ODOO_USER", "admin")
ODOO_PASSWORD = os.getenv("ODOO_PASSWORD", "admin")
API_SECRET_KEY = os.getenv("API_SECRET_KEY", "your_secret_key_here")

# ========== ログ設定 ==========
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ========== DB設定 ==========
engine = create_engine(DATABASE_URL, echo=False)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# ========== SQLAlchemy モデル ==========
class Customer(Base):
    __tablename__ = "mobile_customers"
    
    id = Column(Integer, primary_key=True)
    odoo_customer_id = Column(Integer, unique=True, nullable=True)
    name = Column(String(255))
    address = Column(String(500), nullable=True)
    phone = Column(String(20), nullable=True)
    email = Column(String(255), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    synced = Column(Boolean, default=False)

class Document(Base):
    __tablename__ = "mobile_documents"
    
    id = Column(Integer, primary_key=True)
    odoo_id = Column(Integer, unique=True, nullable=True)
    doc_type = Column(String(50))  # quotation, delivery, invoice, receipt
    customer_id = Column(Integer, ForeignKey("mobile_customers.id"))
    document_date = Column(DateTime)
    items = Column(JSON)  # [{product_name, quantity, unit_price, subtotal}, ...]
    subtotal = Column(Numeric(12, 2))
    tax = Column(Numeric(12, 2))
    total = Column(Numeric(12, 2))
    status = Column(String(50))  # draft, sent, confirmed, paid, etc.
    billing_date = Column(DateTime, nullable=True)
    payment_due_date = Column(DateTime, nullable=True)
    payment_method = Column(String(100), nullable=True)
    paid_date = Column(DateTime, nullable=True)
    notes = Column(String(1000), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    synced = Column(Boolean, default=False)
    sync_timestamp = Column(DateTime, nullable=True)

class SyncLog(Base):
    __tablename__ = "sync_logs"
    
    id = Column(Integer, primary_key=True)
    device_id = Column(String(255))
    operation = Column(String(50))  # sync, upload, download
    document_count = Column(Integer)
    status = Column(String(50))  # success, failure
    message = Column(String(500), nullable=True)
    timestamp = Column(DateTime, default=datetime.utcnow)

# ========== Pydantic モデル ==========
class ItemModel(BaseModel):
    product_name: str
    quantity: float
    unit_price: float
    subtotal: float

class PaymentTermsModel(BaseModel):
    billing_date: Optional[datetime] = None
    payment_due_date: datetime
    payment_method: str  # bank_transfer, cash, etc.

class DocumentModel(BaseModel):
    doc_type: str  # quotation, delivery, invoice, receipt
    customer_id: int
    document_date: datetime
    items: List[ItemModel]
    subtotal: float
    tax: float
    total: float
    payment_terms: PaymentTermsModel
    status: str = "draft"
    notes: Optional[str] = None

class SyncRequest(BaseModel):
    device_id: str
    last_sync_timestamp: Optional[datetime] = None
    documents: List[DocumentModel]

class SyncResponse(BaseModel):
    status: str
    message: str
    synced_documents: int
    new_documents: Optional[List[dict]] = None

# ========== FastAPI アプリ ==========
app = FastAPI(title="Mobile Sync API", version="1.0.0")

# ========== DB セッション依存性 ==========
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ========== 認証 ==========
async def verify_api_key(x_api_key: str = Header(None)):
    if x_api_key != API_SECRET_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")
    return x_api_key

# ========== ヘルパー関数 ==========
def calculate_payment_due_date(billing_date: datetime, pattern: str) -> datetime:
    """
    支払期限を計算
    patterns: 
    - "immediate": 即支払い（当日）
    - "end_of_month": 末締め翌月末
    - "30days": 30日後
    - "60days": 60日後
    """
    if pattern == "immediate":
        return billing_date
    elif pattern == "end_of_month":
        # 翌月末
        next_month = billing_date + relativedelta(months=1)
        return next_month.replace(day=1) - timedelta(days=1)
    elif pattern == "30days":
        return billing_date + timedelta(days=30)
    elif pattern == "60days":
        return billing_date + timedelta(days=60)
    else:
        # デフォルト：30日後
        return billing_date + timedelta(days=30)

def sync_to_odoo(db: Session, document: Document) -> dict:
    """
    ドキュメントを Odoo に同期
    """
    try:
        # Odoo XML-RPC または REST API を使用してデータを送信
        # ここでは簡略版
        logger.info(f"Syncing document {document.id} to Odoo")
        
        # TODO: Odoo API呼び出し
        # response = odoo_api.create_document(...)
        
        document.synced = True
        document.sync_timestamp = datetime.utcnow()
        db.commit()
        
        return {"status": "success", "odoo_id": document.odoo_id}
    except Exception as e:
        logger.error(f"Error syncing to Odoo: {str(e)}")
        return {"status": "error", "message": str(e)}

# ========== エンドポイント ==========

@app.post("/api/v1/sync", response_model=SyncResponse, dependencies=[Depends(verify_api_key)])
async def sync_documents(request: SyncRequest, db: Session = Depends(get_db)):
    """
    モバイルアプリからのドキュメント同期
    """
    try:
        synced_count = 0
        new_documents = []
        
        for doc in request.documents:
            # 顧客を確認
            customer = db.query(Customer).filter(Customer.id == doc.customer_id).first()
            if not customer:
                logger.warning(f"Customer {doc.customer_id} not found")
                continue
            
            # ドキュメント作成
            db_doc = Document(
                doc_type=doc.doc_type,
                customer_id=doc.customer_id,
                document_date=doc.document_date,
                items=json.dumps([item.model_dump() for item in doc.items]),
                subtotal=doc.subtotal,
                tax=doc.tax,
                total=doc.total,
                status=doc.status,
                billing_date=doc.payment_terms.billing_date,
                payment_due_date=doc.payment_terms.payment_due_date,
                payment_method=doc.payment_terms.payment_method,
                notes=doc.notes,
                synced=False
            )
            
            db.add(db_doc)
            db.commit()
            db.refresh(db_doc)
            
            # Odoo に同期
            sync_result = sync_to_odoo(db, db_doc)
            
            synced_count += 1
            new_documents.append({
                "local_id": db_doc.id,
                "odoo_id": db_doc.odoo_id,
                "doc_type": db_doc.doc_type,
                "status": sync_result["status"]
            })
        
        # ログ記録
        sync_log = SyncLog(
            device_id=request.device_id,
            operation="sync",
            document_count=synced_count,
            status="success",
            message=f"Synced {synced_count} documents"
        )
        db.add(sync_log)
        db.commit()
        
        return SyncResponse(
            status="success",
            message=f"Successfully synced {synced_count} documents",
            synced_documents=synced_count,
            new_documents=new_documents
        )
    
    except Exception as e:
        logger.error(f"Sync error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/v1/customers", dependencies=[Depends(verify_api_key)])
async def get_customers(db: Session = Depends(get_db)):
    """
    顧客一覧取得（オンライン時にマスタ更新）
    """
    try:
        customers = db.query(Customer).all()
        return {
            "status": "success",
            "customers": [
                {
                    "id": c.id,
                    "name": c.name,
                    "address": c.address,
                    "phone": c.phone,
                    "email": c.email
                } for c in customers
            ]
        }
    except Exception as e:
        logger.error(f"Error fetching customers: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/v1/documents/{doc_id}", dependencies=[Depends(verify_api_key)])
async def get_document(doc_id: int, db: Session = Depends(get_db)):
    """
    特定ドキュメント取得
    """
    try:
        doc = db.query(Document).filter(Document.id == doc_id).first()
        if not doc:
            raise HTTPException(status_code=404, detail="Document not found")
        
        return {
            "status": "success",
            "document": {
                "id": doc.id,
                "doc_type": doc.doc_type,
                "customer_id": doc.customer_id,
                "document_date": doc.document_date,
                "items": json.loads(doc.items) if doc.items else [],
                "total": float(doc.total),
                "payment_due_date": doc.payment_due_date,
                "status": doc.status
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching document: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/v1/receipts/{invoice_id}", dependencies=[Depends(verify_api_key)])
async def create_receipt(invoice_id: int, db: Session = Depends(get_db)):
    """
    請求書から領収書を自動生成
    入金1週間以内の場合に発行可能
    """
    try:
        invoice = db.query(Document).filter(
            Document.id == invoice_id,
            Document.doc_type == "invoice"
        ).first()
        
        if not invoice:
            raise HTTPException(status_code=404, detail="Invoice not found")
        
        if not invoice.paid_date:
            raise HTTPException(status_code=400, detail="Invoice not yet paid")
        
        # 入金1週間以内かチェック
        days_since_payment = (datetime.utcnow() - invoice.paid_date).days
        if days_since_payment > 7:
            raise HTTPException(status_code=400, detail="Receipt cannot be issued (payment older than 7 days)")
        
        # 領収書作成
        receipt = Document(
            doc_type="receipt",
            customer_id=invoice.customer_id,
            document_date=datetime.utcnow(),
            items=invoice.items,
            subtotal=invoice.subtotal,
            tax=invoice.tax,
            total=invoice.total,
            status="issued",
            paid_date=invoice.paid_date,
            synced=False
        )
        
        db.add(receipt)
        db.commit()
        db.refresh(receipt)
        
        return {
            "status": "success",
            "receipt_id": receipt.id,
            "message": "Receipt created successfully"
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating receipt: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/v1/health", dependencies=[Depends(verify_api_key)])
async def health_check():
    """
    ヘルスチェック
    """
    return {"status": "ok", "timestamp": datetime.utcnow()}

# ========== DB初期化 ==========
@app.on_event("startup")
async def startup():
    Base.metadata.create_all(bind=engine)
    logger.info("Database tables created")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
