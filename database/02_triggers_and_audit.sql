-- Função para atualizar timestamp e autor
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  NEW.updated_by = auth.uid();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Aplicação automática em todas as tabelas relevantes
DO $$
DECLARE
    t_name text;
    tables text[] := ARRAY[
        'master_client', 'master_person', 'master_class', 'master_subject', 
        'master_academic_period', 'master_user', 'rel_student', 'rel_teacher', 
        'rel_class_schedule', 'trx_assessment', 'trx_grade', 'trx_attendance'
    ];
BEGIN
    FOREACH t_name IN ARRAY tables
    LOOP
        EXECUTE format('ALTER TABLE %I ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();', t_name);
        EXECUTE format('ALTER TABLE %I ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();', t_name);
        EXECUTE format('ALTER TABLE %I ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;', t_name);
        EXECUTE format('ALTER TABLE %I ADD COLUMN IF NOT EXISTS created_by UUID DEFAULT auth.uid();', t_name);
        EXECUTE format('ALTER TABLE %I ADD COLUMN IF NOT EXISTS updated_by UUID;', t_name);
        
        EXECUTE format('CREATE TRIGGER set_timestamp_%I BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();', t_name, t_name);
    END LOOP;
END;
$$;