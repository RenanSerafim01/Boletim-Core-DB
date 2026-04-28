-- ================================================
-- SCRIPTS DE TESTE E EXEMPLOS DE USO DAS FUNCTIONS
-- ================================================

-- ------------------------------------------------------------------------------
-- FUNC 1: calculate_subject_average
-- Retorna a média de um aluno específico em uma turma e disciplina.
-- ------------------------------------------------------------------------------
SELECT calculate_subject_average(
    (SELECT rel_student.id 
     FROM rel_student 
     JOIN master_person ON rel_student.id_master_person = master_person.id 
     WHERE master_person.name = '<NOME_DO_ALUNO>'),
     
    (SELECT id FROM master_class WHERE name = '<NOME_DA_TURMA>'),
    (SELECT id FROM master_subject WHERE name = '<NOME_DA_DISCIPLINA>')
) as "Média Calculada Pela Função";


-- ------------------------------------------------------------------------------
-- FUNC 2: calculate_attendance_percentage
-- Retorna a porcentagem de frequência de um aluno.
-- ------------------------------------------------------------------------------
SELECT calculate_attendance_percentage(
    (SELECT rel_student.id FROM rel_student JOIN master_person ON rel_student.id_master_person = master_person.id WHERE master_person.name = '<NOME_DO_ALUNO>'),
    (SELECT id FROM master_class WHERE name = '<NOME_DA_TURMA>'),
    (SELECT id FROM master_subject WHERE name = '<NOME_DA_DISCIPLINA>')
) as "Frequência Calculada %";


-- ------------------------------------------------------------------------------
-- FUNC 3: check_student_status
-- Verifica se o aluno está Aprovado, Reprovado por Nota, Reprovado por Falta ou Pendente.
-- ------------------------------------------------------------------------------
SELECT 
    (SELECT name FROM master_person p JOIN rel_student s ON p.id = s.id_master_person WHERE s.id = ids.aluno_id) as "Aluno",
    check_student_status(ids.aluno_id, ids.turma_id, ids.materia_id) as "Veredito Final"
FROM (
    SELECT 
        s.id as aluno_id,
        c.id as turma_id,
        sub.id as materia_id
    FROM rel_student s
    JOIN master_person p ON s.id_master_person = p.id
    JOIN master_class c ON c.name = '<NOME_DA_TURMA>'
    JOIN master_subject sub ON sub.name = '<NOME_DA_DISCIPLINA>'
    WHERE p.name = '<NOME_DO_ALUNO>' 
) as ids;


-- ------------------------------------------------------------------------------
-- FUNC 4: classify_student_performance
-- Classifica o desempenho do aluno (Destaque, Bom, Regular, Risco).
-- ------------------------------------------------------------------------------
SELECT 
    (SELECT name FROM master_person p JOIN rel_student s ON p.id = s.id_master_person WHERE s.id = ids.aluno_id) as "Aluno",
    calculate_subject_average(ids.aluno_id, ids.turma_id, ids.materia_id) as "Média Real",
    classify_student_performance(ids.aluno_id, ids.turma_id, ids.materia_id) as "Classificação"
FROM (
    SELECT 
        s.id as aluno_id,
        c.id as turma_id,
        sub.id as materia_id
    FROM rel_student s
    JOIN master_person p ON s.id_master_person = p.id
    JOIN master_class c ON c.name = '<NOME_DA_TURMA>'
    JOIN master_subject sub ON sub.name = '<NOME_DA_DISCIPLINA>'
    WHERE p.name = '<NOME_DO_ALUNO>' 
) as ids;


-- ------------------------------------------------------------------------------
-- FUNC 5: validate_teacher_assignment
-- Valida se um professor tem habilitação/vínculo para lecionar uma matéria.
-- ------------------------------------------------------------------------------
SELECT 
    (SELECT name FROM master_person p JOIN rel_teacher t ON p.id = t.id_master_person WHERE t.id = ids.prof_id) as "Professor",
    (SELECT name FROM master_subject WHERE id = ids.materia_id) as "Matéria Tentada",
    CASE 
        WHEN validate_teacher_assignment(ids.prof_id, ids.materia_id) THEN 'Autorizado'
        ELSE 'Proibido (Sem Habilitação)'
    END as "Status"
FROM (
    SELECT 
        (SELECT id FROM rel_teacher LIMIT 1) as prof_id,
        (SELECT id FROM master_subject LIMIT 1) as materia_id
) as ids;


-- ------------------------------------------------------------------------------
-- FUNC 6: validate_student_enrollment
-- Impede que o mesmo aluno seja matriculado duplicado na mesma turma.
-- ------------------------------------------------------------------------------
SELECT 
    (SELECT name FROM master_person p JOIN rel_student s ON p.id = s.id_master_person WHERE s.id = ids.aluno_id) as "Aluno",
    (SELECT name FROM master_class WHERE id = ids.turma_id) as "Turma Tentada",
    CASE 
        WHEN validate_student_enrollment(ids.aluno_id, ids.turma_id) THEN 'Pode Matricular'
        ELSE 'Bloqueado (Já Matriculado)'
    END as "Status"
FROM (
    SELECT 
       (SELECT rel_student.id FROM rel_student JOIN master_person ON rel_student.id_master_person = master_person.id WHERE master_person.name = '<NOME_DO_ALUNO>') as aluno_id,
       (SELECT id FROM master_class WHERE name = '<NOME_DA_TURMA>') as turma_id
) as ids;


-- ------------------------------------------------------------------------------
-- FUNC 7: validate_grade_entry
-- Valida universalmente se a nota enviada pela API está no range correto (0 a 10).
-- ------------------------------------------------------------------------------
SELECT 
    val_teste as "Nota Tentada",
    CASE 
        WHEN validate_grade_entry(val_teste) THEN 'Válida'
        ELSE 'Inválida'
    END as "Resultado"
FROM (
    VALUES 
        (8.5),   
        (10.0),  
        (0.0),   
        (-1.5),  
        (11.0),  
        (100.0) 
) as t(val_teste);


-- ------------------------------------------------------------------------------
-- FUNC 8: get_student_report_card
-- Retorna o boletim completo formatado de um aluno em uma turma.
-- ------------------------------------------------------------------------------
SELECT * FROM get_student_report_card(
    (SELECT rel_student.id FROM rel_student JOIN master_person ON rel_student.id_master_person = master_person.id WHERE master_person.name = '<NOME_DO_ALUNO>'),
    (SELECT id FROM master_class WHERE name = '<NOME_DA_TURMA>')
);


-- ------------------------------------------------------------------------------
-- FUNC 9: list_students_at_risk
-- Lista todos os alunos de uma turma que estão com nota abaixo da média ou reprovados.
-- ------------------------------------------------------------------------------
SELECT * FROM list_students_at_risk(
    (SELECT id FROM master_class WHERE name = '<NOME_DA_TURMA>')
);


-- ------------------------------------------------------------------------------
-- FUNC 10: get_class_statistics
-- Retorna os KPIs da turma (Média Geral, Maior Nota, Menor Nota, Aprovados/Reprovados).
-- ------------------------------------------------------------------------------
SELECT * FROM get_class_statistics(
    (SELECT id FROM master_class WHERE name = '<NOME_DA_TURMA>'),
    (SELECT id FROM master_subject WHERE name = '<NOME_DA_DISCIPLINA>')
);


-- ------------------------------------------------------------------------------
-- FUNC 11: generate_unique_code
-- Gera as matrículas únicas e sequenciais para novos cadastros (RA e PROF).
-- ------------------------------------------------------------------------------
SELECT 
    generate_unique_code('STUDENT') as "Próximo RA de Aluno",
    generate_unique_code('TEACHER') as "Próxima Matrícula de Prof",
    generate_unique_code('ALIENIGENA') as "Teste de Erro";


-- ------------------------------------------------------------------------------
-- FUNC 12: log_audit
-- Simulação de gravação de ação no log de auditoria interno.
-- ------------------------------------------------------------------------------
SELECT log_audit(
    (SELECT id FROM rel_teacher LIMIT 1), 
    'ALTERACAO_NOTA',                     
    '{"aluno": "<NOME_DO_ALUNO>", "nota_antiga": 5.0, "nota_nova": 9.5}'::JSONB 
);

-- Checando a inserção do Log
SELECT * FROM trx_audit_log ORDER BY created_at DESC;


-- ------------------------------------------------------------------------------
-- FUNC 13: process_period_closing
-- Roda a processo de fechamento de um período letivo para todos os alunos.
-- ------------------------------------------------------------------------------
-- PASSO 1: Descubra os IDs dos períodos executando a query abaixo:

SELECT id, name FROM master_academic_period;

-- PASSO 2: Substitua o UUID abaixo pelo ID do período desejado:

SELECT process_period_closing(
    '<ID_DO_PERIODO_UUID>', 
    (SELECT id FROM rel_teacher LIMIT 1)
);