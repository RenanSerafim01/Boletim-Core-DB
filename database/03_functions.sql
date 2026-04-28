-- Função Calcular Média da Disciplina
CREATE OR REPLACE FUNCTION calculate_subject_average(
    p_student_id UUID,    
    p_class_id UUID,      
    p_subject_id UUID     
)
RETURNS NUMERIC(5,2)      
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_points NUMERIC := 0; 
    v_total_weight NUMERIC := 0; 
    v_average NUMERIC;           
BEGIN
   
    SELECT 
        SUM(trx_grade.grade_value * trx_assessment.weight),
        SUM(trx_assessment.weight)
    INTO 
        v_total_points,
        v_total_weight
    FROM trx_grade
    JOIN trx_assessment ON trx_grade.id_trx_assessment = trx_assessment.id
    JOIN rel_class_schedule ON trx_assessment.id_rel_class_schedule = rel_class_schedule.id
    WHERE 
        trx_grade.id_rel_student = p_student_id          
        AND rel_class_schedule.id_master_class = p_class_id   
        AND rel_class_schedule.id_master_subject = p_subject_id; 

    IF v_total_weight IS NULL OR v_total_weight = 0 THEN
        RETURN NULL;
    END IF;

    v_average := v_total_points / v_total_weight;

    RETURN ROUND(v_average, 2);
END;
$$;


-- Função Calcular Percentual de Frequência
CREATE OR REPLACE FUNCTION calculate_attendance_percentage(
    p_student_id UUID,
    p_class_id UUID,
    p_subject_id UUID
)
RETURNS NUMERIC(5,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_classes INTEGER;
    v_absences INTEGER;
    v_percentage NUMERIC;
BEGIN

    SELECT total_classes 
    INTO v_total_classes
    FROM rel_class_schedule
    WHERE id_master_class = p_class_id 
      AND id_master_subject = p_subject_id;

    IF v_total_classes IS NULL OR v_total_classes = 0 THEN
        RETURN NULL;
    END IF;

    SELECT COUNT(*)
    INTO v_absences
    FROM trx_attendance
    JOIN rel_class_schedule ON trx_attendance.id_rel_class_schedule = rel_class_schedule.id
    WHERE trx_attendance.id_rel_student = p_student_id
      AND rel_class_schedule.id_master_class = p_class_id
      AND rel_class_schedule.id_master_subject = p_subject_id;

    v_percentage := ((v_total_classes::NUMERIC - v_absences::NUMERIC) / v_total_classes::NUMERIC) * 100;

    RETURN ROUND(v_percentage, 1);
END;
$$;

-- Função Verificar Situação do Aluno
CREATE OR REPLACE FUNCTION check_student_status(
    p_student_id UUID,
    p_class_id UUID,
    p_subject_id UUID
)
RETURNS TEXT 
LANGUAGE plpgsql
AS $$
DECLARE
    v_average NUMERIC;           
    v_attendance NUMERIC;        
    v_min_grade NUMERIC;        
    v_min_attendance NUMERIC;    
BEGIN

    SELECT 
        cfg.min_grade_approval,
        cfg.min_attendance
    INTO 
        v_min_grade,
        v_min_attendance
    FROM master_class mc
    JOIN master_client cl ON mc.id_master_client = cl.id
    JOIN cfg_academic_rule cfg ON cl.id = cfg.id_master_client
    WHERE mc.id = p_class_id;

    v_average := calculate_subject_average(p_student_id, p_class_id, p_subject_id);
    v_attendance := calculate_attendance_percentage(p_student_id, p_class_id, p_subject_id);

    IF v_average IS NULL OR v_attendance IS NULL THEN
        RETURN 'PENDENTE'; 
    END IF;

    IF v_attendance < v_min_attendance THEN
        RETURN 'REPROVADO POR FALTA';
    
    ELSIF v_average < v_min_grade THEN
        RETURN 'REPROVADO POR NOTA';
    
    ELSE
        RETURN 'APROVADO';
    END IF;
END;
$$;


-- Função Classificar Desempenho Do Estudante
CREATE OR REPLACE FUNCTION classify_student_performance(
    p_student_id UUID,
    p_class_id UUID,
    p_subject_id UUID
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_average NUMERIC; 
BEGIN
    v_average := calculate_subject_average(p_student_id, p_class_id, p_subject_id);

    IF v_average IS NULL THEN
        RETURN 'SEM NOTA';
    END IF;

    IF v_average >= 9.0 THEN
        RETURN 'DESTAQUE';
        
    ELSIF v_average >= 7.0 THEN
        RETURN 'BOM';
        
    ELSIF v_average >= 5.0 THEN
        RETURN 'REGULAR';
        
    ELSE
        RETURN 'RISCO';
    END IF;
END;
$$;


-- Função Validar Atribuição de Professor
CREATE OR REPLACE FUNCTION validate_teacher_assignment(
    p_teacher_id UUID,  
    p_subject_id UUID   
)
RETURNS BOOLEAN        
LANGUAGE plpgsql
AS $$
DECLARE
    v_exists BOOLEAN;
BEGIN
  
    SELECT EXISTS (
        SELECT 1
        FROM rel_teacher_subject
        WHERE id_rel_teacher = p_teacher_id   
          AND id_master_subject = p_subject_id
    ) INTO v_exists;

    RETURN v_exists;
END;
$$;


-- Função Validar Matrícula de Aluno
CREATE OR REPLACE FUNCTION validate_student_enrollment(
    p_student_id UUID,
    p_class_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_already_enrolled BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM rel_student_class
        WHERE id_rel_student = p_student_id
          AND id_master_class = p_class_id
    ) INTO v_already_enrolled;
    
    IF v_already_enrolled THEN
        RETURN FALSE; 
    ELSE
        RETURN TRUE;  
    END IF;
END;
$$;


-- Função Validar Lançamento de Nota
CREATE OR REPLACE FUNCTION validate_grade_entry(
    p_grade_value NUMERIC
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    
    IF p_grade_value >= 0 AND p_grade_value <= 10 THEN
        RETURN TRUE;  
    ELSE
        RETURN FALSE; 
    END IF;
END;
$$;


-- Função Obter Boletim do Aluno
CREATE OR REPLACE FUNCTION get_student_report_card(
    p_student_id UUID,
    p_class_id UUID
)
RETURNS TABLE (
    disciplina TEXT,
    media NUMERIC,
    frequencia NUMERIC,
    situacao TEXT,
    classificacao TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        master_subject.name::TEXT AS disciplina,
        
        calculate_subject_average(p_student_id, p_class_id, master_subject.id) AS media,
        calculate_attendance_percentage(p_student_id, p_class_id, master_subject.id) AS frequencia,
        check_student_status(p_student_id, p_class_id, master_subject.id) AS situacao,
        classify_student_performance(p_student_id, p_class_id, master_subject.id) AS classificacao
        
    FROM rel_class_schedule
    JOIN master_subject ON rel_class_schedule.id_master_subject = master_subject.id
    WHERE rel_class_schedule.id_master_class = p_class_id;
END;
$$;


-- Função Listar Alunos em Risco
CREATE OR REPLACE FUNCTION list_students_at_risk(
    p_class_id UUID
)
RETURNS TABLE (
    aluno TEXT,
    disciplina TEXT,
    situacao TEXT,
    nota_atual NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        master_person.name::TEXT AS aluno,
        master_subject.name::TEXT AS disciplina,
        
        check_student_status(rel_student.id, p_class_id, master_subject.id) AS situacao,
        calculate_subject_average(rel_student.id, p_class_id, master_subject.id) AS nota_atual
        
    FROM rel_student_class
   
    JOIN rel_student ON rel_student_class.id_rel_student = rel_student.id
    JOIN master_person ON rel_student.id_master_person = master_person.id
    
    JOIN rel_class_schedule ON rel_class_schedule.id_master_class = p_class_id
    JOIN master_subject ON rel_class_schedule.id_master_subject = master_subject.id
    
    WHERE rel_student_class.id_master_class = p_class_id
    
    AND (
           check_student_status(rel_student.id, p_class_id, master_subject.id) LIKE 'REPROVADO'
        OR classify_student_performance(rel_student.id, p_class_id, master_subject.id) = 'RISCO'
    );
END;
$$;


-- Função Estatísticas da Turma
CREATE OR REPLACE FUNCTION get_class_statistics(
    p_class_id UUID,
    p_subject_id UUID
)
RETURNS TABLE (
    media_geral NUMERIC,
    maior_nota NUMERIC,
    menor_nota NUMERIC,
    total_alunos INTEGER,
    qtd_aprovados INTEGER,
    qtd_reprovados INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH notas_alunos AS (
        SELECT 
            calculate_subject_average(rel_student.id, p_class_id, p_subject_id) AS media_individual,
            check_student_status(rel_student.id, p_class_id, p_subject_id) AS status_individual
        FROM rel_student_class
        JOIN rel_student ON rel_student_class.id_rel_student = rel_student.id
        WHERE rel_student_class.id_master_class = p_class_id
    )
    SELECT 
        ROUND(AVG(media_individual), 2) AS media_geral,
        MAX(media_individual) AS maior_nota,
        MIN(media_individual) AS menor_nota,
        COUNT(*)::INTEGER AS total_alunos,
        
        SUM(CASE WHEN status_individual = 'APROVADO' THEN 1 ELSE 0 END)::INTEGER AS qtd_aprovados,
        
        SUM(CASE WHEN status_individual LIKE 'REPROVADO' THEN 1 ELSE 0 END)::INTEGER AS qtd_reprovados
        
    FROM notas_alunos;
END;
$$;


-- Função Gerar Código Único
CREATE OR REPLACE FUNCTION generate_unique_code(
    p_type TEXT 
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_year TEXT;
    v_seq INTEGER;
    v_prefix TEXT;
BEGIN
 
    v_year := TO_CHAR(CURRENT_DATE, 'YYYY');

    IF p_type = 'STUDENT' THEN
        v_prefix := 'RA';
      
        SELECT COUNT(*) + 1 INTO v_seq FROM rel_student;
        
    ELSIF p_type = 'TEACHER' THEN
        v_prefix := 'PROF';
      
        SELECT COUNT(*) + 1 INTO v_seq FROM rel_teacher;
        
    ELSE
        RETURN 'ERRO: TIPO INVALIDO';
    END IF;

    RETURN v_prefix || '-' || v_year || '-' || LPAD(v_seq::TEXT, 4, '0');
END;
$$;


-- Função Registrar Auditoria
CREATE OR REPLACE FUNCTION log_audit(
    p_user_id UUID,
    p_action TEXT,
    p_details JSONB
)
RETURNS VOID 
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO trx_audit_log (user_id, action_type, details)
    VALUES (p_user_id, p_action, p_details);
END;
$$;


-- Função Processar Fechamento de Período
CREATE OR REPLACE FUNCTION process_period_closing(
    p_period_id UUID, 
    p_user_id UUID    
)
RETURNS TEXT 
LANGUAGE plpgsql
AS $$
DECLARE
    v_count_processed INTEGER := 0; 
BEGIN
    
    PERFORM log_audit(p_user_id, 'FECHAMENTO_PERIODO_INICIO', jsonb_build_object('period_id', p_period_id));
    
    SELECT COUNT(*)
    INTO v_count_processed
    FROM rel_class_schedule cs
    JOIN master_class mc ON cs.id_master_class = mc.id
    JOIN rel_student_class sc ON mc.id = sc.id_master_class
    WHERE mc.id_master_academic_period = p_period_id;

    PERFORM log_audit(p_user_id, 'FECHAMENTO_PERIODO_FIM', jsonb_build_object('total_alunos', v_count_processed));

    RETURN 'Fechamento concluído com sucesso. Total de alunos processados: ' || v_count_processed;

EXCEPTION WHEN OTHERS THEN

    PERFORM log_audit(p_user_id, 'ERRO_FECHAMENTO', jsonb_build_object('erro', SQLERRM));
    RETURN 'Erro ao fechar o período: ' || SQLERRM;
END;
$$;