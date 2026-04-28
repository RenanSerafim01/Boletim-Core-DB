-- Criação de ENUMs 
CREATE TYPE enum_period_type AS ENUM ('BIMESTRAL', 'TRIMESTRAL', 'SEMESTRAL', 'ANUAL');
CREATE TYPE enum_assessment_type AS ENUM ('PROVA', 'TRABALHO', 'SIMULADO');
CREATE TYPE enum_enrollment_status AS ENUM ('ATIVO', 'TRANCADO', 'FORMADO');

-- Tabelas Mestres
CREATE TABLE master_client (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    document_number TEXT UNIQUE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE master_person (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    cpf TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    birth_date DATE
);

CREATE TABLE master_user (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    master_auth UUID UNIQUE NOT NULL,
    master_person UUID REFERENCES master_person(id)
);

CREATE TABLE master_academic_period (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_master_client UUID REFERENCES master_client(id),
    name TEXT NOT NULL,
    period_type enum_period_type,
    start_date DATE,
    end_date DATE
);

CREATE TABLE master_class (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_master_client UUID REFERENCES master_client(id),
    id_master_academic_period UUID REFERENCES master_academic_period(id),
    name TEXT NOT NULL,
    code TEXT
);

CREATE TABLE master_subject (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_master_client UUID REFERENCES master_client(id),
    name TEXT NOT NULL,
    code TEXT,
    is_active BOOLEAN DEFAULT TRUE
);

-- Tabelas de Configuração e Relacionamento
CREATE TABLE cfg_academic_rule (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_master_client UUID REFERENCES master_client(id),
    min_grade_approval FLOAT4 DEFAULT 6.0,
    min_attendance FLOAT4 DEFAULT 75.0
);

CREATE TABLE rel_student (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_master_client UUID REFERENCES master_client(id),
    id_master_person UUID REFERENCES master_person(id),
    ra TEXT UNIQUE,
    enrollment_status enum_enrollment_status DEFAULT 'ATIVO'
);

CREATE TABLE rel_teacher (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_master_client UUID REFERENCES master_client(id),
    id_master_person UUID REFERENCES master_person(id),
    hire_date DATE,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE rel_student_class (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_rel_student UUID REFERENCES rel_student(id),
    id_master_class UUID REFERENCES master_class(id)
);

CREATE TABLE rel_class_schedule (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_master_class UUID REFERENCES master_class(id),
    id_master_subject UUID REFERENCES master_subject(id),
    id_rel_teacher UUID REFERENCES rel_teacher(id),
    total_classes INT4
);

-- Tabelas Transacionais
CREATE TABLE trx_assessment (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_rel_class_schedule UUID REFERENCES rel_class_schedule(id),
    name TEXT NOT NULL,
    weight FLOAT4,
    scheduled_date DATE,
    assessment_type enum_assessment_type
);

CREATE TABLE trx_grade (
    id BIGSERIAL PRIMARY KEY,
    id_trx_assessment UUID REFERENCES trx_assessment(id),
    id_rel_student UUID REFERENCES rel_student(id),
    grade_value FLOAT4 CHECK (grade_value >= 0 AND grade_value <= 10)
);

CREATE TABLE trx_attendance (
    id BIGSERIAL PRIMARY KEY,
    id_rel_class_schedule UUID REFERENCES rel_class_schedule(id),
    id_rel_student UUID REFERENCES rel_student(id),
    date DATE NOT NULL,
    justification TEXT
);

CREATE TABLE trx_audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    user_id UUID,
    action_type TEXT,
    details JSONB
);