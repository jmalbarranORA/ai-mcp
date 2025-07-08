import oracledb
from oracledb import Connection, Cursor
import os
from sentence_transformers import SentenceTransformer
import numpy as np
from array import array

import dotenv

# Load .env al environment variables (to be read as os.environ["VARIABLE"])
dotenv.load_dotenv()


os.environ["TNS_ADMIN"] = os.environ["DEMOMCB_WALLET_FOLDER"]

# === CONNECTING USING oracledb (thin mode) ===
connection: Connection = oracledb.connect(
    user=os.environ["DEMOMCB_DEMOUSER_USER"],
    password=os.environ["DEMOMCB_DEMOUSER_PASSWORD"],
    dsn=os.environ["DEMOMCB_SERVICE"],
    config_dir=os.environ["DEMOMCB_WALLET_FOLDER"],
    wallet_location=os.environ["DEMOMCB_WALLET_FOLDER"],
    wallet_password=os.environ["DEMOMCB_WALLET_PASSWORD"]
)

cursor: Cursor = connection.cursor()

# === CONSULT THE PRODUCT TABLE ===
cursor.execute("SELECT id, code, description FROM products")
rows: list[tuple[int, str, str]] = cursor.fetchall()

ids: list[tuple[int, str, str]] = []
descriptions: list = []

for row in rows:
    ids.append((row[0], row[1], row[2]))
    descriptions.append(row[2])

# === EMBEDDING GENERATION ===
model: SentenceTransformer = SentenceTransformer(os.environ["AI_MODEL"])
embeddings: np.ndarray = model.encode(descriptions, convert_to_numpy=True)

if not embeddings.any():
    raise "Error generating embeddings" 

vector_length = len(embeddings[0])
vector_class = str(embeddings[0][0].__class__.__name__)

 
# === CREATION OF EMBEDDINGS TABLE (if it does not exist) ===
cursor.execute(f"""
               BEGIN
                   EXECUTE IMMEDIATE '
                        CREATE TABLE product_embeddings (
                            id NUMBER PRIMARY KEY,
                            code VARCHAR2(100),
                            description VARCHAR2(4000),
                            embeddings VECTOR({vector_length}, {vector_class})
                        )';
                        EXCEPTION
                            WHEN OTHERS THEN
                                IF SQLCODE != -955 THEN
                                    RAISE;
                                END IF;
               END;
               """)

# === INSERTING OR UPDATING DATA ===
for (id_, code, description), embedding in zip(ids, embeddings):
    # vector_bytes = vector.astype(np.float32).tobytes()
    array_embedding: array = array("f", embedding)
    cursor.execute("""
        MERGE INTO product_embeddings tgt
        USING (SELECT :id AS id FROM dual) src
        ON (tgt.id = src.id)
        WHEN MATCHED THEN
            UPDATE SET code = :code, description = :description, embeddings = :embeddings
        WHEN NOT MATCHED THEN
            INSERT (id, code, description, embeddings)
            VALUES (:id, :code, :description, :embeddings)
    """, {
        "id": id_,
        "code": code,
        "description": description,
        "embeddings": array_embedding
    })

connection.commit()
cursor.close()
connection.close()

print("✅ Vectors saved with success in Oracle Database.")