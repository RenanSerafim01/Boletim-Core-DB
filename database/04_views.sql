-- View de Boletim Consolidado
CREATE OR REPLACE VIEW view_boletim_consolidado WITH (security_invoker = true) AS
SELECT 
    master_client.name AS "Escola",
    master_academic_period.name AS "Período",
    master_class.name AS "Turma",
    master_person.name AS "Aluno",
    master_subject.name AS "Disciplina",
    ROUND((SUM(trx_grade.grade_value * trx_assessment.weight) / NULLIF(SUM(trx_assessment.weight), 0))::numeric, 1) AS "Média Final",
    cfg_academic_rule.min_grade_approval AS "Média Exigida",
    ROUND((100.0 * (rel_class_schedule.total_classes - COUNT(trx_attendance.id)) / NULLIF(rel_class_schedule.total_classes, 0))::numeric, 1) AS "Frequência %",
    cfg_academic_rule.min_attendance AS "Freq. Exigida",
    CASE 
        WHEN (100.0 * (rel_class_schedule.total_classes - COUNT(trx_attendance.id)) / NULLIF(rel_class_schedule.total_classes, 0)) < cfg_academic_rule.min_attendance THEN 'REPROVADO POR FALTA'
        WHEN (SUM(trx_grade.grade_value * trx_assessment.weight) / NULLIF(SUM(trx_assessment.weight), 0)) >= cfg_academic_rule.min_grade_approval THEN 'APROVADO'
        ELSE 'REPROVADO POR NOTA'
    END AS "Situação Final"
FROM trx_grade
JOIN trx_assessment ON trx_grade.id_trx_assessment = trx_assessment.id
JOIN rel_class_schedule ON trx_assessment.id_rel_class_schedule = rel_class_schedule.id
JOIN master_subject ON rel_class_schedule.id_master_subject = master_subject.id
JOIN rel_student ON trx_grade.id_rel_student = rel_student.id
JOIN master_person ON rel_student.id_master_person = master_person.id
JOIN master_class ON rel_class_schedule.id_master_class = master_class.id
JOIN master_academic_period ON master_class.id_master_academic_period = master_academic_period.id
JOIN master_client ON master_class.id_master_client = master_client.id
JOIN cfg_academic_rule ON master_client.id = cfg_academic_rule.id_master_client
LEFT JOIN trx_attendance ON trx_attendance.id_rel_class_schedule = rel_class_schedule.id AND trx_attendance.id_rel_student = rel_student.id
GROUP BY 
    master_client.name, master_academic_period.name, master_class.name, master_person.name, 
    master_subject.name, rel_class_schedule.total_classes, cfg_academic_rule.min_grade_approval, cfg_academic_rule.min_attendance;


-- View de Performance da Turma 
CREATE OR REPLACE VIEW view_performance_turma WITH (security_invoker = true) AS
SELECT 
    "Escola", "Período", "Turma", "Disciplina",
    COUNT(*) AS "Qtd Alunos",
    ROUND(AVG("Média Final"), 1) AS "Média Geral da Sala",
    SUM(CASE WHEN "Média Final" < 4.0 THEN 1 ELSE 0 END) AS "Notas 0-4 (Crítico)",
    SUM(CASE WHEN "Média Final" >= 4.0 AND "Média Final" < 6.0 THEN 1 ELSE 0 END) AS "Notas 4-6 (Baixo)",
    SUM(CASE WHEN "Média Final" >= 6.0 AND "Média Final" < 8.0 THEN 1 ELSE 0 END) AS "Notas 6-8 (Médio)",
    SUM(CASE WHEN "Média Final" >= 8.0 THEN 1 ELSE 0 END) AS "Notas 8-10 (Alto)",
    ROUND((100.0 * SUM(CASE WHEN "Situação Final" LIKE 'APROVADO%' THEN 1 ELSE 0 END) / COUNT(*))::numeric, 0) AS "% Aprovação",
    COALESCE(STRING_AGG("Aluno", ', ') FILTER (WHERE "Situação Final" LIKE 'REPROVADO%'), 'Nenhum') AS "Alunos em Risco",
    COALESCE(STRING_AGG("Aluno", ', ') FILTER (WHERE "Média Final" >= 9.0), 'Nenhum') AS "Destaques"
FROM view_boletim_consolidado
GROUP BY "Escola", "Período", "Turma", "Disciplina";


--  View do Boletim Anual
CREATE OR REPLACE VIEW view_boletim_anual WITH (security_invoker = true) AS
WITH dados_brutos AS (
    SELECT 
        master_client.name AS escola,
        EXTRACT(YEAR FROM master_academic_period.start_date) AS ano_letivo,
        master_person.name AS aluno,
        master_subject.name AS disciplina,
        master_academic_period.name AS periodo_nome,
        (SUM(trx_grade.grade_value * trx_assessment.weight) / NULLIF(SUM(trx_assessment.weight), 0)) AS media_periodo,
        rel_class_schedule.total_classes AS aulas_no_periodo,
        COUNT(trx_attendance.id) AS faltas_no_periodo,
        cfg_academic_rule.min_grade_approval,
        cfg_academic_rule.min_attendance
    FROM trx_grade
    JOIN trx_assessment ON trx_grade.id_trx_assessment = trx_assessment.id
    JOIN rel_class_schedule ON trx_assessment.id_rel_class_schedule = rel_class_schedule.id
    JOIN master_subject ON rel_class_schedule.id_master_subject = master_subject.id
    JOIN rel_student ON trx_grade.id_rel_student = rel_student.id
    JOIN master_person ON rel_student.id_master_person = master_person.id
    JOIN master_class ON rel_class_schedule.id_master_class = master_class.id
    JOIN master_academic_period ON master_class.id_master_academic_period = master_academic_period.id
    JOIN master_client ON master_class.id_master_client = master_client.id
    JOIN cfg_academic_rule ON master_client.id = cfg_academic_rule.id_master_client
    LEFT JOIN trx_attendance ON trx_attendance.id_rel_class_schedule = rel_class_schedule.id AND trx_attendance.id_rel_student = rel_student.id
    GROUP BY 
        master_client.name, master_academic_period.start_date, master_academic_period.name,
        master_person.name, master_subject.name, rel_class_schedule.total_classes,
        cfg_academic_rule.min_grade_approval, cfg_academic_rule.min_attendance
)
SELECT 
    escola AS "Escola", ano_letivo AS "Ano", aluno AS "Aluno", disciplina AS "Disciplina",
    STRING_AGG(periodo_nome || ': ' || ROUND(media_periodo::numeric, 1), ' | ') AS "Histórico de Notas",
    ROUND(AVG(media_periodo)::numeric, 1) AS "Média Anual",
    ROUND((100.0 * (SUM(aulas_no_periodo) - SUM(faltas_no_periodo)) / NULLIF(SUM(aulas_no_periodo), 0))::numeric, 1) AS "Frequência Anual %",
    CASE 
        WHEN (100.0 * (SUM(aulas_no_periodo) - SUM(faltas_no_periodo)) / NULLIF(SUM(aulas_no_periodo), 0)) < min_attendance THEN 'REPROVADO POR FALTA'
        WHEN AVG(media_periodo) < min_grade_approval THEN 'REPROVADO POR NOTA'
        ELSE 'APROVADO NO ANO' 
    END AS "Situação Anual"
FROM dados_brutos
GROUP BY escola, ano_letivo, aluno, disciplina, min_grade_approval, min_attendance;


-- View do Boletim Oficial 
CREATE OR REPLACE VIEW view_boletim_oficial WITH (security_invoker = true) AS
SELECT 
    master_client.name AS "Escola",
    master_academic_period.name AS "Período",
    master_class.name AS "Turma",
    master_person.name AS "Aluno",
    master_subject.name AS "Matéria",
    trx_assessment.name AS "Avaliação",
    trx_grade.grade_value AS "Nota Lançada",
    trx_assessment.assessment_type::text AS "Tipo"
FROM trx_grade
JOIN trx_assessment ON trx_grade.id_trx_assessment = trx_assessment.id
JOIN rel_class_schedule ON trx_assessment.id_rel_class_schedule = rel_class_schedule.id
JOIN master_subject ON rel_class_schedule.id_master_subject = master_subject.id
JOIN rel_student ON trx_grade.id_rel_student = rel_student.id
JOIN master_person ON rel_student.id_master_person = master_person.id
JOIN master_class ON rel_class_schedule.id_master_class = master_class.id
JOIN master_academic_period ON master_class.id_master_academic_period = master_academic_period.id
JOIN master_client ON master_class.id_master_client = master_client.id;


-- View do Painel do Professor
CREATE OR REPLACE VIEW view_painel_professor WITH (security_invoker = true) AS
SELECT 
    master_person.name AS "Professor",
    master_academic_period.name AS "Período",
    master_class.name AS "Turma",
    master_subject.name AS "Disciplina",
    COUNT(DISTINCT rel_student_class.id_rel_student) AS "Qtd Alunos",
    COUNT(DISTINCT trx_assessment.id) AS "Provas Criadas",
    MIN(trx_assessment.scheduled_date) FILTER (WHERE trx_assessment.scheduled_date >= CURRENT_DATE) AS "Próxima Prova",
    CASE 
        WHEN COUNT(DISTINCT trx_assessment.id) = 0 THEN 'PENDENTE'
        ELSE 'TUDO OK'
    END AS "Status"
FROM rel_teacher
JOIN master_person ON rel_teacher.id_master_person = master_person.id
JOIN rel_class_schedule ON rel_teacher.id = rel_class_schedule.id_rel_teacher
JOIN master_class ON rel_class_schedule.id_master_class = master_class.id
JOIN master_academic_period ON master_class.id_master_academic_period = master_academic_period.id
JOIN master_subject ON rel_class_schedule.id_master_subject = master_subject.id
LEFT JOIN rel_student_class ON master_class.id = rel_student_class.id_master_class
LEFT JOIN trx_assessment ON rel_class_schedule.id = trx_assessment.id_rel_class_schedule
GROUP BY 
    master_person.name, master_academic_period.name, master_class.name, master_subject.name;