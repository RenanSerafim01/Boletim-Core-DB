# 🎓 Boletim-Core-DB - Arquitetura Multi-tenant & Segurança Avançada

Este repositório contém a arquitetura de banco de dados relacional para um SaaS Educacional (EduTrack). O projeto foi desenhado com foco em **escalabilidade**, **isolamento de dados (Multi-tenant)** e **segurança em nível de linha (RLS)** utilizando PostgreSQL.

## 🚀 Arquitetura e Tecnologias

O banco de dados foi estruturado separando responsabilidades entre tabelas Mestras (`master_`), de Relacionamento (`rel_`) e Transacionais (`trx_`). 

**Principais features de Engenharia de Dados:**
* **Multi-tenant Design:** Suporte a múltiplas escolas no mesmo banco de dados com isolamento total de informações.
* **Row Level Security (RLS):** Políticas de segurança nativas do PostgreSQL garantindo que Professores e Alunos acessem apenas os dados pertencentes à sua escola e/ou turmas.
* **Tipagem Forte (ENUMs):** Utilização de tipos enumerados customizados para status de matrículas, tipos de período e avaliações, garantindo integridade e performance.
* **Audit Trails & Triggers:** Colunas `created_at`, `updated_at`, `deleted_at` (Soft Delete) e `updated_by` gerenciadas automaticamente por Gatilhos (Triggers) no banco, sem depender do backend.
* **Regras de Negócio Nativas (PL/pgSQL):** Funções complexas processadas diretamente no banco (cálculo de médias ponderadas, apuração de faltas, geração de matrículas únicas e fechamento de período) para aliviar a carga da API.

## 📊 Diagrama de Entidade-Relacionamento (ERD)

![Diagrama do Banco de Dados](database/diagrama.png) 
*(Nota: Certifique-se de salvar a imagem que geramos no dbdiagram.io com o nome `diagrama.png` dentro da pasta `database` para que ela apareça aqui!)*

## 📁 Estrutura do Repositório

Os scripts SQL foram modularizados respeitando a ordem correta de execução do DDL:

1. `01_ddl_tables_and_enums.sql`: Criação de tipos, tabelas e constraints.
2. `02_triggers_and_audit.sql`: Automação de timestamps e auditoria.
3. `03_functions.sql`: Regras de negócio (cálculos e validações).
4. `04_views.sql`: Relatórios otimizados e seguros (Security Invoker).
5. `05_security_and_rls.sql`: Ativação do Row Level Security e Políticas.
6. `06_indexes.sql`: Índices para otimização de consultas e RLS.
7. `07_usage_examples.sql`: Template de consultas documentadas para uso da API.

## 🛠️ Como testar localmente
Basta executar os scripts da pasta `database/` em ordem sequencial no seu cliente PostgreSQL ou painel do Supabase. O arquivo `07_usage_examples.sql` contém queries parametrizadas (placeholders) para simular o comportamento do backend.
