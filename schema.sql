
------------------------------------------------------------------------------------------------------------------------
-- Сущности:

-- Перечисления
CREATE TYPE user_role           AS ENUM ('STUDENT', 'EDUCATOR', 'ADMIN');
CREATE TYPE user_status         AS ENUM ('ACTIVE', 'BLOCKED');
CREATE TYPE financial_status    AS ENUM ('GRANT', 'PAID');
CREATE TYPE academic_degree     AS ENUM ('BACHELOR', 'MASTER', 'DOCTOR');
CREATE TYPE study_form          AS ENUM ('FULL_TIME', 'PART_TIME');

-- REQUIRED    Обязательный компонент  (ОК)
-- UNIVERSITY  Вузовский компонент     (ВК)
-- ELECTIVE    Компонент по выбору     (КВ)
CREATE TYPE choose_type         AS ENUM ('REQUIRED', 'UNIVERSITY', 'ELECTIVE');

-- Тип для статуса апелляции
CREATE TYPE appeal_status AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

-- Таблица групп образовательных программ
CREATE TABLE group_educational_program (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE,
    title VARCHAR(255) NOT NULL,
    years_of_study INT CHECK (years_of_study > 0)
);

-- Таблица образовательных программ
CREATE TABLE educational_program (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    group_educational_program_id INT NOT NULL REFERENCES group_educational_program(id) ON DELETE CASCADE,
    code VARCHAR(20) NOT NULL UNIQUE,
    title VARCHAR(255) NOT NULL,
    academic_degree academic_degree NOT NULL,
    study_form study_form NOT NULL,
    education_lang VARCHAR(20) NOT NULL
);

-- Таблица дисциплин
CREATE TABLE discipline (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    educational_program_id INT NOT NULL REFERENCES educational_program(id) ON DELETE CASCADE,
    code VARCHAR(20) NOT NULL UNIQUE,
    title VARCHAR(255) NOT NULL,
    choose_type choose_type NOT NULL,
    number_of_credits INT CHECK (number_of_credits > 0)
);

-- Таблица пользователей
CREATE TABLE t_user (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    firstname VARCHAR(100) NOT NULL,
    surname VARCHAR(100) NOT NULL,
    lastname VARCHAR(100),
    phone_number VARCHAR(20),

    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password TEXT NOT NULL,
    role user_role NOT NULL,
    status user_status NOT NULL DEFAULT 'ACTIVE'
);

-- Паспортные данные
CREATE TABLE passport (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    iin CHAR(12) UNIQUE NOT NULL,
    date_of_birth DATE NOT NULL,
    citizenship VARCHAR(100),
    nationality VARCHAR(100)
);

-- Adviser отдельно от User
-- Просто, чтобы была информация об эдвайзере
CREATE TABLE adviser (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    firstname VARCHAR(100) NOT NULL,
    surname VARCHAR(100) NOT NULL,
    lastname VARCHAR(100) NOT NULL,
    phone_number VARCHAR(20),
    email VARCHAR(255) UNIQUE
);

-- Основные группы студентов
CREATE TABLE main_group (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    educational_program_id INT REFERENCES educational_program(id) ON DELETE SET NULL,
    course_number INT NOT NULL,
    year_of_creation INT NOT NULL,
    group_size INT,
    is_active BOOLEAN DEFAULT TRUE,

    adviser_id INT REFERENCES adviser(id) ON DELETE SET NULL,
    adviser_assigned_date DATE
);

-- Студенты
CREATE TABLE student (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INT REFERENCES t_user(id) ON DELETE CASCADE,
    passport_id INT REFERENCES passport(id) ON DELETE SET NULL,

    telegram_username VARCHAR(100) NOT NULL,
    additional_email VARCHAR(255),

    date_of_admission DATE NOT NULL,
    educational_program_id INT REFERENCES educational_program(id) ON DELETE SET NULL,
    financial_status financial_status NOT NULL,
    date_of_grant_award DATE,
    course_number INT NOT NULL,
    main_group_id INT REFERENCES main_group(id)
);

-- Преподаватели
CREATE TABLE educator (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INT UNIQUE REFERENCES t_user(id) ON DELETE CASCADE,

    degree VARCHAR(100),
    position VARCHAR(100)
);

CREATE TABLE archived_educator (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    original_user_id INT,                  -- educator.user_id (может быть NULL, если удалён)
    full_name TEXT NOT NULL,               -- Полное имя в виде, пригодном для отображения
    degree VARCHAR(100),                   -- Учёная степень на момент архивации
    position VARCHAR(100),                 -- Должность
    archived_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE archived_adviser (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name TEXT NOT NULL,
    phone_number VARCHAR(20),
    email VARCHAR(255),
    archived_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Семестровый ИУП студента
CREATE TABLE iep (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id INT NOT NULL REFERENCES student(id),
    educational_program_id INT NOT NULL REFERENCES educational_program(id),

    -- достаточно одного значения, т.к. семестр проходит в рамках одного года (либо до нового года, либо после)
    study_year INT NOT NULL,

    semester SMALLINT NOT NULL CHECK (semester IN (1, 2)),
    semester_credits INT NOT NULL,

    adviser_id INT REFERENCES adviser(id),
    archived_adviser_id INT REFERENCES archived_adviser(id),

    created_at TIMESTAMP DEFAULT NOW()
);

-- В таблице хранятся копии данных дисциплины на момент создания ИУП
-- на случай, если потом дисциплина будет переименована или модифицирована.
CREATE TABLE iep_discipline (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    iep_id INT NOT NULL REFERENCES iep(id) ON DELETE CASCADE,
    discipline_id INT NOT NULL REFERENCES discipline(id),
    code VARCHAR(20) NOT NULL,             -- Копия на момент формирования
    title VARCHAR(255) NOT NULL,           -- Копия на момент формирования
    choose_type choose_type NOT NULL,
    number_of_credits INT CHECK (number_of_credits > 0)
);

-- Преподаватели, назначенные на дисциплину в рамках ИУП
CREATE TABLE iep_discipline_educator (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    iep_discipline_id INT NOT NULL REFERENCES iep_discipline(id) ON DELETE CASCADE,
    
    educator_id INT REFERENCES educator(id),
    archived_educator_id INT REFERENCES archived_educator(id)
);

-- Таблица учебных групп
CREATE TABLE study_group (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    discipline_id INT NOT NULL REFERENCES discipline(id) ON DELETE CASCADE,

    -- достаточно одного значения, т.к. учебная группа
    -- активна в рамках одного семестра (либо до нового года, либо после)
    study_year INT NOT NULL,

    semester SMALLINT NOT NULL CHECK (semester IN (1, 2)),
    is_active BOOLEAN DEFAULT TRUE,
    is_main_group BOOLEAN DEFAULT FALSE
);

-- Таблица связи студент-группа (Many-to-Many)
CREATE TABLE student_study_group (
    student_id INT NOT NULL REFERENCES student(id) ON DELETE CASCADE,
    study_group_id INT NOT NULL REFERENCES study_group(id) ON DELETE CASCADE,
    PRIMARY KEY (student_id, study_group_id)
);

-- Таблица связи преподаватель-группа (Many-to-Many)
CREATE TABLE educator_study_group (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    educator_id INT NOT NULL REFERENCES educator(id) ON DELETE CASCADE,
    study_group_id INT NOT NULL REFERENCES study_group(id) ON DELETE CASCADE,
    UNIQUE (educator_id, study_group_id)
);

-- Таблица заданий
CREATE TABLE assignment (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    educator_study_group_id INT NOT NULL REFERENCES educator_study_group(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    deadline TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Вложения к заданиям
CREATE TABLE assignment_files (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    assignment_id INT NOT NULL REFERENCES assignment(id) ON DELETE CASCADE,
    file_url TEXT NOT NULL,
    filename TEXT NOT NULL,
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Отправки заданий
CREATE TABLE assignment_submission (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    assignment_id INT NOT NULL REFERENCES assignment(id) ON DELETE CASCADE,
    student_id INT NOT NULL REFERENCES student(id) ON DELETE CASCADE,
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    comment TEXT,
    reviewed_at TIMESTAMP,
    grade INT CHECK (grade BETWEEN 0 AND 100),
    feedback TEXT,
    is_late BOOLEAN DEFAULT FALSE
);

-- Вложения к отправкам
CREATE TABLE assignment_submission_files (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    assignment_submission_id INT NOT NULL REFERENCES assignment_submission(id) ON DELETE CASCADE,
    file_url TEXT NOT NULL,
    filename TEXT NOT NULL,
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица тестов
CREATE TABLE test (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    educator_study_group_id INT NOT NULL REFERENCES educator_study_group(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Банк вопросов
CREATE TABLE test_question_bank (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    test_id INT NOT NULL REFERENCES test(id) ON DELETE CASCADE,
    question_text TEXT NOT NULL,
    image_url TEXT,
    max_options INT CHECK (max_options BETWEEN 1 AND 10),
    correct_answers_count INT CHECK (correct_answers_count >= 1)
);

-- Варианты ответа на вопрос
CREATE TABLE test_question_option (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    question_id INT NOT NULL REFERENCES test_question_bank(id) ON DELETE CASCADE,
    option_text TEXT NOT NULL,
    image_url TEXT,
    is_correct BOOLEAN
);

-- Сессия прохождения теста студентом
CREATE TABLE test_session (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    test_id INT NOT NULL REFERENCES test(id) ON DELETE CASCADE,
    student_id INT NOT NULL REFERENCES student(id) ON DELETE CASCADE,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    submitted_at TIMESTAMP,
    score REAL,
    is_completed BOOLEAN DEFAULT FALSE
);

-- 1. Вопросы, выданные студенту в тестовой сессии.
-- 2. Перед прохождением для каждого студента рандомно выбирается
--    подмножество из всех загруженных вопросов для конкретного теста
CREATE TABLE test_session_question (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    session_id INT NOT NULL REFERENCES test_session(id) ON DELETE CASCADE,
    question_id INT NOT NULL REFERENCES test_question_bank(id) ON DELETE CASCADE
);

-- Ответы на вопросы
CREATE TABLE test_session_answer (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    session_question_id INT NOT NULL REFERENCES test_session_question(id) ON DELETE CASCADE,
    selected_option_id INT NOT NULL REFERENCES test_question_option(id) ON DELETE CASCADE
);

-- Апелляции на результат теста
CREATE TABLE test_appeal (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    test_session_id INT NOT NULL REFERENCES test_session(id) ON DELETE CASCADE,
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reason TEXT NOT NULL,
    response TEXT,
    reviewed_by INT REFERENCES educator(id) ON DELETE SET NULL, -- educator_id
    reviewed_at TIMESTAMP,
    status appeal_status DEFAULT 'PENDING'
);
