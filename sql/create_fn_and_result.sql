
-- DROP TYPES (se existirem)
DROP TYPE product_result_tab;
DROP TYPE product_result;


-- Criação de um tipo de tabela para retorno da função
CREATE OR REPLACE TYPE product_result AS OBJECT (
                                                       code VARCHAR2(50),
                                                       description VARCHAR2(4000),
                                                       similarity NUMBER
                                                   );
/

CREATE OR REPLACE TYPE product_result_tab AS TABLE OF product_result;
/

-- Função de busca fonética e por palavras-chave
CREATE OR REPLACE FUNCTION fn_advanced_search(p_termos IN VARCHAR2)
    RETURN product_result_tab PIPELINED
AS
    v_termos SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST();
    v_token VARCHAR2(1000);
    v_description VARCHAR2(4000);
    v_score NUMBER;
    v_dummy NUMBER;
BEGIN
    -- Dividir os termos da busca
    FOR i IN 1..REGEXP_COUNT(p_termos, '\S+') LOOP
            v_termos.EXTEND;
            v_termos(i) := LOWER(REGEXP_SUBSTR(p_termos, '\S+', 1, i));
        END LOOP;

    -- Loop pelos products
    FOR prod IN (SELECT code, description FROM products) LOOP
            v_description := LOWER(prod.description);
            v_score := 0;

            -- Avaliar cada termo da busca
            FOR i IN 1..v_termos.COUNT LOOP
                    v_token := v_termos(i);

                    -- 3 pontos se encontrar diretamente
                    IF v_description LIKE '%' || v_token || '%' THEN
                        v_score := v_score + 3;
                    ELSE
                        -- 2 pontos se foneticamente similar
                        BEGIN
                            SELECT 1 INTO v_dummy FROM dual
                            WHERE SOUNDEX(v_token) IN (
                                SELECT SOUNDEX(REGEXP_SUBSTR(v_description, '\w+', 1, LEVEL))
                                FROM dual
                                CONNECT BY LEVEL <= REGEXP_COUNT(v_description, '\w+')
                            );
                            v_score := v_score + 2;
                        EXCEPTION
                            WHEN NO_DATA_FOUND THEN NULL;
                        END;

                        -- 1 ponto se similar por escrita
                        BEGIN
                            SELECT 1 INTO v_dummy FROM dual
                            WHERE EXISTS (
                                SELECT 1
                                FROM (
                                         SELECT REGEXP_SUBSTR(v_description, '\w+', 1, LEVEL) AS palavra
                                         FROM dual
                                         CONNECT BY LEVEL <= REGEXP_COUNT(v_description, '\w+')
                                     )
                                WHERE UTL_MATCH.EDIT_DISTANCE(palavra, v_token) <= 2
                            );
                            v_score := v_score + 1;
                        EXCEPTION
                            WHEN NO_DATA_FOUND THEN NULL;
                        END;
                    END IF;
                END LOOP;

            -- Só retorna se houver ao menos algum match
            IF v_score > 0 THEN
                PIPE ROW(product_result(prod.code, prod.description, v_score));
            END IF;
        END LOOP;

    RETURN;
END;
/

-- Grant para execução, se necessário:
GRANT EXECUTE ON fn_advanced_search TO PUBLIC;


-- Testes
SELECT *
FROM TABLE(fn_advanced_search('harry'))
ORDER BY similarity DESC;
