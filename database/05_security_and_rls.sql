-- ================================
-- FUNÇÕES DE CONTEXTO DE SEGURANÇA 
-- ================================

CREATE OR REPLACE FUNCTION get_user_client_id() RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT COALESCE(
    (SELECT t.id_master_client FROM public.rel_teacher t JOIN public.master_user u ON u.master_person = t.id_master_person WHERE u.master_auth = auth.uid() LIMIT 1),
    (SELECT s.id_master_client FROM public.rel_student s JOIN public.master_user u ON u.master_person = s.id_master_person WHERE u.master_auth = auth.uid() LIMIT 1)
  );
$$;

CREATE OR REPLACE FUNCTION get_user_person_id() RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT master_person FROM public.master_user WHERE master_auth = auth.uid();
$$;

CREATE OR REPLACE FUNCTION is_user_teacher() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.rel_teacher t JOIN public.master_user u ON u.master_person = t.id_master_person
    WHERE u.master_auth = auth.uid() AND t.is_active = true 
  );
$$;

CREATE OR REPLACE FUNCTION is_user_student() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.rel_student s JOIN public.master_user u ON u.master_person = s.id_master_person
    WHERE u.master_auth = auth.uid()
  );
$$;

-- ==============================
-- ATIVAÇÃO DO ROW LEVEL SECURITY
-- ==============================

ALTER TABLE master_client ENABLE ROW LEVEL SECURITY;
ALTER TABLE master_person ENABLE ROW LEVEL SECURITY;
ALTER TABLE master_class ENABLE ROW LEVEL SECURITY;
ALTER TABLE master_subject ENABLE ROW LEVEL SECURITY;
ALTER TABLE master_academic_period ENABLE ROW LEVEL SECURITY;
ALTER TABLE master_user ENABLE ROW LEVEL SECURITY;
ALTER TABLE rel_class_schedule ENABLE ROW LEVEL SECURITY;
ALTER TABLE rel_student ENABLE ROW LEVEL SECURITY;
ALTER TABLE rel_student_class ENABLE ROW LEVEL SECURITY;
ALTER TABLE rel_teacher ENABLE ROW LEVEL SECURITY;
ALTER TABLE rel_teacher_subject ENABLE ROW LEVEL SECURITY;
ALTER TABLE trx_assessment ENABLE ROW LEVEL SECURITY;
ALTER TABLE trx_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE trx_grade ENABLE ROW LEVEL SECURITY;
ALTER TABLE cfg_academic_rule ENABLE ROW LEVEL SECURITY;

-- ===================
-- POLÍTICAS DE ACESSO 
-- ===================

--- TABELAS MASTER ---
CREATE POLICY "master_client_select_own" ON public.master_client FOR SELECT TO authenticated
USING (id = get_user_client_id());

CREATE POLICY "master_user_select_own" ON public.master_user FOR SELECT TO authenticated
USING (master_auth = auth.uid());

CREATE POLICY "master_person_select" ON public.master_person FOR SELECT TO authenticated
USING (
    (id = get_user_person_id()) 
    OR 
    (is_user_teacher() AND (
        (id IN (SELECT id_master_person FROM rel_student WHERE id_master_client = get_user_client_id())) 
        OR 
        (id IN (SELECT id_master_person FROM rel_teacher WHERE id_master_client = get_user_client_id()))
    ))
);

CREATE POLICY "master_class_select_own_client" ON public.master_class FOR SELECT TO authenticated
USING (id_master_client = get_user_client_id());

CREATE POLICY "master_subject_select_own_client" ON public.master_subject FOR SELECT TO authenticated
USING (id_master_client = get_user_client_id());

CREATE POLICY "period_select_own_client" ON public.master_academic_period FOR SELECT TO authenticated
USING (id_master_client = get_user_client_id());

CREATE POLICY "cfg_academic_rule_select_own_client" ON public.cfg_academic_rule FOR SELECT TO authenticated
USING (id_master_client = get_user_client_id());

--- TABELAS DE RELACIONAMENTO ---
CREATE POLICY "rel_teacher_select_own_client" ON public.rel_teacher FOR SELECT TO authenticated
USING (id_master_client = get_user_client_id());

CREATE POLICY "rel_student_select" ON public.rel_student FOR SELECT TO authenticated
USING ((id_master_person = get_user_person_id()) OR (is_user_teacher() AND id_master_client = get_user_client_id()));

CREATE POLICY "grade_horaria_escola" ON public.rel_class_schedule FOR SELECT TO authenticated
USING (id_master_class IN (SELECT id FROM master_class WHERE id_master_client = get_user_client_id()));

--- TABELAS TRANSACIONAIS ---
CREATE POLICY "trx_assessment_select" ON public.trx_assessment FOR SELECT TO authenticated
USING (id_rel_class_schedule IN (
    SELECT cs.id FROM rel_class_schedule cs JOIN master_class c ON c.id = cs.id_master_class
    WHERE c.id_master_client = get_user_client_id()
));

-- Notas: Aluno vê a sua, Professor vê/lança da sua turma
CREATE POLICY "aluno_ve_propria_nota" ON public.trx_grade FOR SELECT TO authenticated
USING (is_user_student() AND (EXISTS (
    SELECT 1 FROM rel_student 
    WHERE rel_student.id = trx_grade.id_rel_student AND rel_student.id_master_person = get_user_person_id()
)));

CREATE POLICY "professor_ve_notas" ON public.trx_grade FOR SELECT TO authenticated
USING (is_user_teacher() AND (id_trx_assessment IN (
    SELECT a.id FROM trx_assessment a JOIN rel_class_schedule cs ON cs.id = a.id_rel_class_schedule JOIN rel_teacher t ON t.id = cs.id_rel_teacher
    WHERE t.id_master_person = get_user_person_id()
)));

CREATE POLICY "professor_lanca_notas" ON public.trx_grade FOR INSERT TO authenticated
WITH CHECK (is_user_teacher() AND (id_trx_assessment IN (
    SELECT a.id FROM trx_assessment a JOIN rel_class_schedule cs ON cs.id = a.id_rel_class_schedule JOIN rel_teacher t ON t.id = cs.id_rel_teacher
    WHERE t.id_master_person = get_user_person_id()
)));

-- Faltas: Aluno vê a sua, Professor vê/lança da sua turma
CREATE POLICY "aluno_ve_propria_falta" ON public.trx_attendance FOR SELECT TO authenticated
USING (is_user_student() AND id_rel_student = (SELECT id FROM rel_student WHERE id_master_person = get_user_person_id() LIMIT 1));

CREATE POLICY "professor_ve_faltas" ON public.trx_attendance FOR SELECT TO authenticated
USING (is_user_teacher() AND (id_rel_class_schedule IN (
    SELECT cs.id FROM rel_class_schedule cs JOIN rel_teacher t ON t.id = cs.id_rel_teacher
    WHERE t.id_master_person = get_user_person_id()
)));

CREATE POLICY "professor_lanca_faltas" ON public.trx_attendance FOR INSERT TO authenticated
WITH CHECK (is_user_teacher() AND (id_rel_class_schedule IN (
    SELECT cs.id FROM rel_class_schedule cs JOIN rel_teacher t ON t.id = cs.id_rel_teacher
    WHERE t.id_master_person = get_user_person_id()
)));