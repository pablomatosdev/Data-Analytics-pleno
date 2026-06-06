-- REESTRUTURAÇÃO DO BANCO PARA ANALYTICS AVANÇADO
DROP TABLE IF EXISTS entregas;
DROP TABLE IF EXISTS pedidos;
DROP TABLE IF EXISTS clientes;
DROP TABLE IF EXISTS transportes;

CREATE TABLE clientes (
    id_clientes INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    idade INT CHECK (idade >= 0),
    status_cliente VARCHAR(20) DEFAULT 'Ativo' -- Essencial para análise de Churn
);

CREATE TABLE transportes (
    id_transportadora INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    status_transportadora VARCHAR(20) DEFAULT 'Ativo'
);

CREATE TABLE pedidos (
    id_pedidos INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_clientes INT NOT NULL,
    status_pedido VARCHAR(50),
    valor_total NUMERIC(10, 2),
    data_pedido DATE NOT NULL, -- Nova coluna para análises temporais
    CONSTRAINT fk_pedidos_clientes FOREIGN KEY (id_clientes) REFERENCES clientes(id_clientes)
);

CREATE TABLE entregas (
    id_entregas INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pedidos INT NOT NULL, -- Agora vinculado diretamente ao pedido correto!
    id_transportadora INT NOT NULL,
    status_entrega VARCHAR(50),
    valor_frete NUMERIC(10, 2),
    data_envio DATE,      -- Para cálculo de Lead Time
    data_entrega_efetiva DATE, -- Para cálculo de SLA e Prazo Médio
    prazo_prometido_dias INT,
    CONSTRAINT fk_entregas_pedidos FOREIGN KEY (id_pedidos) REFERENCES pedidos(id_pedidos),
    CONSTRAINT fk_entregas_transportadoras FOREIGN KEY (id_transportadora) REFERENCES transportes(id_transportadora)
);

-- DADOS DE TESTE (Massa de dados realista de E-commerce)
INSERT INTO clientes (nome, email, idade, status_cliente) VALUES  
('Ana Silva', 'ana@email.com', 28, 'Ativo'), ('Carlos Souza', 'carlos@email.com', 35, 'Ativo'),
('Beatriz Santos', 'beatriz@email.com', 19, 'Inativo'), ('Ricardo Lima', 'ricardo@email.com', 42, 'Ativo'),
('Juliana Costa', 'juliana@email.com', 55, 'Ativo'), ('Fernando Oliveira', 'fernando@email.com', 61, 'Inativo'),
('Mariana Almeida', 'mariana@email.com', 23, 'Ativo'), ('Gabriel Pires', 'gabriel@email.com', 31, 'Ativo'),
('Lucas Martins', 'lucas@email.com', 17, 'Ativo'), ('Camila Rocha', 'camila@email.com', 48, 'Ativo');

INSERT INTO transportes (nome, status_transportadora) VALUES  
('LogExpress', 'Ativo'), ('Alfafretes', 'Ativo'), ('VeloCargo', 'Ativo');

INSERT INTO pedidos (id_clientes, status_pedido, valor_total, data_pedido) VALUES  
(1, 'Entregue', 150.00, '2026-05-01'), (1, 'Entregue', 90.00, '2026-05-15'),
(2, 'Entregue', 450.00, '2026-05-02'), (2, 'Em Rota', 600.00, '2026-05-28'),
(3, 'Cancelado', 120.00, '2026-05-03'), (4, 'Entregue', 1200.00, '2026-05-04'),
(4, 'Entregue', 150.00, '2026-05-20'), (5, 'Entregue', 320.00, '2026-05-05'),
(5, 'Entregue', 500.00, '2026-05-25'), (6, 'Processando', 55.00, '2026-05-06'),
(7, 'Entregue', 210.00, '2026-05-07'), (7, 'Entregue', 130.00, '2026-05-22'),
(8, 'Entregue', 95.00, '2026-05-08'), (10, 'Entregue', 850.00, '2026-05-09'),
(10, 'Cancelado', 40.00, '2026-05-10');

INSERT INTO entregas (id_pedidos, id_transportadora, status_entrega, valor_frete, data_envio, data_entrega_efetiva, prazo_prometido_dias) VALUES  
(1, 1, 'Sucesso', 15.00, '2026-05-02', '2026-05-05', 5),
(2, 2, 'Sucesso', 25.00, '2026-05-16', '2026-05-22', 5), -- Estourou o prazo (6 dias)
(3, 1, 'Sucesso', 50.00, '2026-05-03', '2026-05-06', 4),
(6, 2, 'Sucesso', 120.00, '2026-05-05', '2026-05-08', 3),
(8, 3, 'Sucesso', 35.00, '2026-05-06', '2026-05-12', 7),
(9, 3, 'Sucesso', 40.00, '2026-05-26', '2026-05-29', 4),
(11, 1, 'Atrasado', 18.00, '2026-05-08', '2026-05-16', 5), -- Estourou o prazo (8 dias)
(12, 3, 'Sucesso', 20.00, '2026-05-23', '2026-05-25', 2),
(13, 3, 'Sucesso', 12.00, '2026-05-09', '2026-05-11', 3),
(14, 2, 'Falha', 90.00, '2026-05-10', NULL, 6);


--Recita total e ticket medio
select SUM(valor_total) AS receita_total,
ROUND(AVG(valor_total),2) AS tickte_medio FROM pedidos
where status_pedido <> 'Cancelado';

-- Clientes Ativos vs. Churn
SELECT COUNT(CASE WHEN status_cliente = 'Ativo' THEN 1 END) AS clientes_ativos, 
COUNT(CASE WHEN status_cliente = 'Inativo' THEN 1 END) AS clientes_Inativos
FROM clientes;

--Clientes Recorrentes
SELECT COUNT(*) total_clientes_recorrentes FROM (
    SELECT id_clientes FROM pedidos
    WHERE status_pedido = 'Entregue'
    GROUP BY id_clientes
    HAVING COUNT(id_clientes) > 1
);

--Quem são os nossos top 3 clientes em quantidade de pedidos gerados?
SELECT c.nome, COUNT(p.id_pedidos) AS total_pedidos FROM clientes c
JOIN pedidos p
ON p.id_clientes = c.id_clientes
GROUP BY c.id_clientes, c.nome
ORDER BY total_pedidos DESC
LIMIT 3;

-- Quem são os clientes que trazem o maior volume financeiro para a empresa?
SELECT c.nome, SUM(p.valor_total) AS receita_total_pedidos FROM clientes c
JOIN pedidos p
ON p.id_clientes = c.id_clientes
WHERE status_pedido = 'Entregue'
GROUP BY c.id_clientes, c.nome
ORDER BY receita_total_pedidos DESC;

--Qual cliente tem o maior histórico de pedidos cancelados?
SELECT c.nome, COUNT(p.id_pedidos) AS total_pedidos_Cncelados FROM clientes c
JOIN pedidos p
ON p.id_clientes = c.id_clientes
WHERE status_pedido = 'Cancelado'
GROUP BY c.id_clientes, c.nome
ORDER BY total_pedidos_Cncelados DESC;

--Liste os pedidos cujo valor seja maior do que a média de consumo do seu respectivo cliente.
SELECT c.nome,p_externo.id_clientes, p_externo.id_pedidos, p_externo.valor_total FROM pedidos p_externo
JOIN  clientes c
ON c.id_clientes = p_externo.id_clientes
WHERE p_externo.valor_total > (SELECT AVG(p_interno.valor_total) FROM pedidos p_interno
WHERE p_interno.id_clientes = p_externo.id_clientes );

-- Busque o registro do pedido mais recente de cada cliente sem usar GROUP BY nas colunas principais.
SELECT c.nome, p_ext.id_clientes, p_ext.id_pedidos, p_ext.data_pedido
FROM pedidos p_ext
JOIN  clientes c
ON c.id_clientes = p_ext.id_clientes
WHERE p_ext.data_pedido = (
    SELECT MAX(p_int.data_pedido) 
    FROM pedidos p_int 
    WHERE p_int.id_clientes = p_ext.id_clientes
);

-- Quero ver todos os pedidos na tela, mas com uma coluna mostrando qual a posição (ranking) daquele pedido no histórico de gastos do próprio cliente.
SELECT id_clientes, 
    id_pedidos, 
    valor_total,
    DENSE_RANK() OVER(PARTITION BY id_clientes ORDER BY valor_total desc ) AS rankig
    FROM pedidos
GROUP BY id_pedidos;


--pedidos de cada cliente comparando diretamente o valor do pedido atual com o valor do pedido imediatamente anterior que ele fez.
SELECT 
    id_clientes, 
    data_pedido, 
    valor_total AS pedido_atual,
    LAG(valor_total, 1) OVER(PARTITION BY id_clientes ORDER BY data_pedido) AS pedido_anterior
FROM pedidos;


--Quantos dias, em média, as transportadoras levam desde o envio do produto até a entrega efetiva na casa do cliente?
SELECT 
    t.nome,
    ROUND (AVG(e.data_entrega_efetiva - e.data_envio), 1) AS prazo_medio_dias
    FROM entregas e
    JOIN transportes t ON t.id_transportadora = e.id_transportadora
    WHERE e.data_entrega_efetiva IS NOT null
GROUP BY t.id_transportadora, t.nome;


--Qual o percentual de entregas feitas rigorosamente dentro do prazo prometido por transportadora?
SELECT 
    t.nome,
    COUNT(e.id_entregas) AS Total_de_entregas,
    ROUND(COUNT(CASE WHEN (e.data_entrega_efetiva - e.data_envio) <=  e.prazo_prometido_dias THEN 1 END) * 100.0 / COUNT(e.id_entregas), 2) AS taxa_SLA_percentual 
    FROM entregas e 
    JOIN transportadoras t ON t.id_transportadora = e.id_transportadora
GROUP BY t.id_transportadora, t.nome;

--Pergunta de Negócio: Unindo o menor custo de frete, menor taxa de falhas e o melhor cumprimento de prazos, qual parceiro lidera o ranking de eficiência?
SELECT t.nome AS transportadora,
    COUNT(e.id_entregas) AS total_de_entrgas,
    ROUND(AVG(e.valor_frete),2) AS media_vlr_frete,
    COUNT(CASE WHEN e.status_entrega =  'Falha' THEN 1 END) AS Total_de_falhas,
    ROUND(COUNT (CASE WHEN (e.data_entrega_efetiva - e.data_envio) <= e.prazo_prometido_dias THEN 1 END) * 100 / COUNT(e.id_entregas), 2) AS taxa_sla
FROM entregas e
    JOIN transportadoras t
    ON t.id_transportadora = e.id_transportadora
GROUP BY t.id_transportadora, t.nome
ORDER BY taxa_sla, media_vlr_frete ASC;

--todas as principais métricas calculadas em uma única estrutura limpa e centralizada para o time de BI
CREATE OR REPLACE VIEW v_analytics_ecommerce_master AS
SELECT 
    p.id_pedidos,
    p.data_pedido,
    p.status_pedido,
    p.valor_total AS receita_pedido,
    c.nome AS nome_cliente,
    c.idade AS idade_cliente,
    c.status_cliente,
    t.nome AS transportadora_responsavel,
    e.valor_frete,
    (e.data_entrega_efetiva - e.data_envio) AS dias_para_entregar,
    e.prazo_prometido_dias,
    CASE 
        WHEN (e.data_entrega_efetiva - e.data_envio) <= e.prazo_prometido_dias THEN 'No Prazo'
        WHEN e.status_entrega = 'Falha' THEN 'Falha/Extravio'
        ELSE 'Atrasado'
    END AS status_sla
FROM pedidos p
JOIN clientes c ON c.id_clientes = p.id_clientes
LEFT JOIN entregas e ON e.id_pedidos = p.id_pedidos
LEFT JOIN transportes t ON t.id_transportadora = e.id_transportadora;
