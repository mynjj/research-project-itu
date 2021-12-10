create table al_objects(
    id integer primary key,
    object_type text check(object_type in ('Codeunit', 'Page', 'Report', 'Table', 'PageExtension', 'TableExtension')),
    object_id integer
);

create table al_lines(
    id integer primary key,
    al_object_id integer,
    line_number integer,
    line_type text check(line_type in ('Object', 'Trigger/Function', 'Empty', 'Code')),
    hash text,

    foreign key(al_object_id) references al_objects(id)
);

create table tests(
    id integer primary key, 
    codeunit_id integer,
    name text
);

create table test_procedures(
    id integer primary key,
    test_id integer,
    procedure_name text,

    foreign key(test_id) references tests(id)
);

create table test_runs(
    id integer primary key,
    test_procedure_id integer,
    duration real,
    result text,
    --result text check(result in ('Failure', 'Success', 'Skipped')),

    foreign key(test_procedure_id) references test_procedures(id)
);

create table coverage_data(
    id integer primary key,
    test_procedure_id integer,
    al_line_id integer,
    coverage_type text,
    --coverage_type text check(coverage_type in ('NA', 'Covered', 'Not Covered', 'Partially Covered')),
    hits integer,

    foreign key(test_procedure_id) references test_procedures(id),
    foreign key(al_line_id) references al_lines(id)
);
