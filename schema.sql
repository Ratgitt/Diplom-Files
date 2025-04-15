



-- registerUser() - Админы(сотрудники универа) создают учетные записи преподавателей и студентов.
--                  Учетные записи админов будут создаваться вручную разработчиками платформы.
-- authenticateUser() - индивидуально для всех пользователей
-- changePassword() - индивидуально для всех пользователей (старый + новый пароль)
-- resetPassword() - Отправка на почту временного кода для сброса пароля.

PasswordResetToken { --пример токена сброса
   long id;
   string email;
   uuid token;
   timestamp expirationTime;
}






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
    original_user_id INT,                      -- educator.user_id (может быть NULL, если удалён)
    full_name TEXT NOT NULL,                   -- Полное имя в виде, пригодном для отображения
    degree VARCHAR(100),                               -- Учёная степень на момент архивации
    position VARCHAR(100),                             -- Должность
    archived_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE archived_adviser (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name TEXT NOT NULL,
    phone_number VARCHAR(20),
    email VARCHAR(255),
    archived_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 1. Семестровый ИУП студента
CREATE TABLE iep (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id INT NOT NULL REFERENCES student(id),
    educational_program_id INT NOT NULL REFERENCES educational_program(id),
    start_year INT NOT NULL,
    end_year INT NOT NULL,
    semester SMALLINT NOT NULL CHECK (semester IN (1, 2)),
    semester_credits INT NOT NULL,

    adviser_id INT REFERENCES adviser(id),
    archived_adviser_id INT REFERENCES archived_adviser(id)

    created_at TIMESTAMP DEFAULT NOW()
);




















virtual_group (
   id
   discipline_id
   year_period (for ex. 2021-2022)
   semester
   is_active
)

student_virtual_group (
   student_id
   virtual_group_id
)

educator_virtual_group (
   educator_id
   virtual_group_id
)

group_educational_program (
   id
   code
   title
   years_of_study
)

educational_program (
   id
   group_educational_program_id
   code
   title
   academic_degree (BACHELOR, MASTER, DOCTOR)
   study_form (FULL_TIME, PART_TIME)
   education_lang
)

-- REQUIRED    Обязательный компонент  (ОК)
-- UNIVERSITY  Вузовский компонент     (ВК)
-- ELECTIVE    Компонент по выбору     (КВ)
discipline (
   id
   educational_program_id

   code
   title
   choose_type (REQUIRED, UNIVERSITY, ELECTIVE)
   number_of_credits
)

CREATE TYPE iep_descipline AS (
   discipline_id
   choose_type
   code
   title
   number_of_credits
   educators int[] -- список educator_id
)

-- ИУП - Individual Education Plan
IEP (
   student_id
   educational_program_id
   year_period
   semester
   semester_credits
   adviser_id
   discipline_list iep_descipline[]  -- "iep_discipline" custom type
)






--------------------------------------
-- Планы:
-- 1) ЗАДАНИЯ + ОЦЕНКИ + ТРАНСКРИПТ
-- 2) РАСПИСАНИЕ + АКАДЕМ.КАЛЕНДАРЬ (график преподов, силлабусы, помещения и т.д.)
-- 3) ТЕСТИРОВАНИЕ и АПЕЛЛЯЦИИ
-- 4) УВЕДОМЛЕНИЯ

-- Добавить возможность просматривать syllabus по каждому предмету. Файл предварительно загружается преподавателем.

4 типа занятий:
- лекции
- лабораторные
- SIS
- TSIS



---------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ЗАДАНИЯ

assignment (
   id
   educator_id           -- Кто выдал задание
   study_group_id        -- Какой учебной группе
   title                 -- Название задания
   description           -- Описание (текст/тема)
   deadline              -- Дата и время дедлайна
   created_at
   updated_at
   is_active             -- Чтобы можно было архивировать/скрывать
);

-- Препод может загружать несколько вложений для задания
assignment_files (
   assignment_id
   file_url        -- Например, PDF с заданием
);

-- Отправки заданий студентами
assignment_submission (
   id
   assignment_id
   student_id
   submitted_at
   grade                 -- Можно null, если еще не оценено (оценка от 0 до 100)
   feedback TEXT         -- Комментарий от преподавателя
   is_late BOOLEAN       -- Было ли просрочено
);

-- Можно загружать несколько файлов при сдаче дз
assignment_submission_files (
   assignment_submission_id
   file_url              -- Загруженный файл
);