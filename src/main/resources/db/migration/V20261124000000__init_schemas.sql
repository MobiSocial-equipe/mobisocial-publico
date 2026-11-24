-- Migration: V20261124000000__init_schemas.sql
-- Garante os schemas dedicados por servico SOA (ADR 03)
CREATE SCHEMA IF NOT EXISTS users;
CREATE SCHEMA IF NOT EXISTS rides;
CREATE SCHEMA IF NOT EXISTS payments;
CREATE SCHEMA IF NOT EXISTS notifications;
