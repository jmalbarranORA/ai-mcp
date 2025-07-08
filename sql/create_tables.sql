CREATE TABLE products (
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code VARCHAR2(50),
    description VARCHAR2(4000)
);

CREATE INDEX idx_text_description ON products(description)
INDEXTYPE IS CTXSYS.CONTEXT;

-- Table main: INVOICE
CREATE TABLE INVOICE (
    no_invoice          VARCHAR2(20) PRIMARY KEY,
    code_customer       VARCHAR2(20) NOT NULL,
    name_customer       VARCHAR2(100),
    value_total         NUMBER(15, 2),
    date_print          DATE,
    city                VARCHAR2(100),
    state               VARCHAR2(2)   -- Ex: SP, RJ, MG
);

-- Table of itens: ITEM_INVOICE
CREATE TABLE ITEM_INVOICE (
    no_invoice          VARCHAR2(20) NOT NULL,
    no_item             NUMBER(5) NOT NULL,
    code_ean            VARCHAR2(20),
    description_product VARCHAR2(200),
    value_unitary       NUMBER(12, 4),
    quantity            NUMBER(10, 2),
    value_total         NUMBER(15, 2),
    value_taxes         NUMBER(15, 2),
    
    -- Primary key
    CONSTRAINT PK_ITEM_INVOICE PRIMARY KEY (NO_INVOICE, NO_ITEM),

    -- Foreign key for INVOICE
    CONSTRAINT FK_ITEM_INVOICE FOREIGN KEY (NO_INVOICE)
        REFERENCES INVOICE (NO_INVOICE)
        ON DELETE CASCADE
);

-- Index to accelerate searches for invoice item
CREATE INDEX IDX_ITEM_INVOICE_EAN ON ITEM_INVOICE (CODE_EAN);