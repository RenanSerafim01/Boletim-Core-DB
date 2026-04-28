CREATE INDEX IF NOT EXISTS idx_user_auth ON master_user(master_auth);
CREATE INDEX IF NOT EXISTS idx_user_person ON master_user(master_person);

CREATE INDEX IF NOT EXISTS idx_student_person ON rel_student(id_master_person);
CREATE INDEX IF NOT EXISTS idx_student_client ON rel_student(id_master_client);

CREATE INDEX IF NOT EXISTS idx_teacher_person ON rel_teacher(id_master_person);
CREATE INDEX IF NOT EXISTS idx_teacher_client ON rel_teacher(id_master_client);

CREATE INDEX IF NOT EXISTS idx_subject_client ON master_subject(id_master_client);
CREATE INDEX IF NOT EXISTS idx_class_client ON master_class(id_master_client);
CREATE INDEX IF NOT EXISTS idx_period_client ON master_academic_period(id_master_client);

CREATE INDEX IF NOT EXISTS idx_trx_assessment_schedule ON trx_assessment(id_rel_class_schedule);

CREATE INDEX IF NOT EXISTS idx_grade_student ON trx_grade(id_rel_student);
CREATE INDEX IF NOT EXISTS idx_grade_assessment ON trx_grade(id_trx_assessment);

CREATE INDEX IF NOT EXISTS idx_attendance_student ON trx_attendance(id_rel_student);
CREATE INDEX IF NOT EXISTS idx_attendance_schedule ON trx_attendance(id_rel_class_schedule);