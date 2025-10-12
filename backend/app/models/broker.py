from sqlalchemy import String, DateTime
from sqlalchemy.sql import func
from sqlalchemy.orm import Mapped, mapped_column
from app.db import Base

class Broker(Base):
    __tablename__ = "brokers"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    broker_name: Mapped[str] = mapped_column(String, nullable=False)
    client_id: Mapped[str] = mapped_column(String, nullable=False)
    auth_token: Mapped[str] = mapped_column(String, nullable=False)
    connected_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
