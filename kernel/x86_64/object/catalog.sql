-- EdgeRun canonical object catalog authoring view.
--
-- This SQL is not the runtime authority and must not become an external build
-- dependency. It is the compact, queryable editing/index form for finite code
-- vocabularies. The materialized authority remains the checked .erobj objects.
-- Workflows load the relation set into memory first; only useful state changes
-- are materialized back to disk as object/source updates. Do not use an on-disk
-- database file as active engine state.

pragma foreign_keys = on;

create table object_kind (
  kind_id integer primary key,
  name text not null unique,
  body_magic text
);

insert into object_kind(kind_id, name, body_magic) values
  (1,  'bytes',   null),
  (2,  'tree',    null),
  (4,  'receipt', 'ERCMAT01'),
  (8,  'code',    'ERCODE01'),
  (16, 'isa',     'ERISA001');

create table isa (
  isa_id integer primary key,
  name text not null unique,
  object_path text not null unique
);

insert into isa(isa_id, name, object_path) values
  (1, 'x86_64',  'kernel/x86_64/object/x86_64_isa.erobj'),
  (2, 'x86_32',  'kernel/x86_64/object/x86_32_isa.erobj'),
  (3, 'aarch64', 'kernel/x86_64/object/aarch64_isa.erobj'),
  (4, 'arm32',   'kernel/x86_64/object/arm32_isa.erobj'),
  (5, 'wasm',    'kernel/x86_64/object/wasm_isa.erobj');

create table body_format (
  magic text primary key,
  version integer not null,
  purpose text not null,
  materialized_as_kind integer not null references object_kind(kind_id)
);

insert into body_format(magic, version, purpose, materialized_as_kind) values
  ('ERISA001', 1, 'finite instruction-set or single-instruction definition table', 16),
  ('ERFORM01', 1, 'instruction form: instruction id plus operand/encoding/effect shape', 1),
  ('ERREG001', 1, 'single register or register-like runtime state location', 1),
  ('ERREGSET', 1, 'register namespace index for an ISA', 1),
  ('ERTYPE01', 1, 'value type, pointer type, reference type, or pseudo type', 1),
  ('EROPK001', 1, 'operand kind category used by operand shapes and concrete operands', 1),
  ('EROPSH01', 1, 'operand shape signature over operand kind slots', 1),
  ('ERADDR01', 1, 'addressing mode vocabulary for memory operands', 1),
  ('EROPER01', 1, 'concrete operand object referencing type/register/addressing/value data', 1),
  ('ERENC001', 1, 'encoding pattern object for materializing a form with operands', 1),
  ('ERFUNC01', 1, 'function graph root over records, operands, encodings, and edges', 1),
  ('ERCODE01', 1, 'bootstrap fixed-size code records', 8),
  ('ERCMAT01', 1, 'materialization receipt body', 4);

create table value_type (
  type_id integer primary key,
  name text not null unique,
  class_id integer not null,
  width_bits integer not null,
  flags integer not null default 0,
  object_path text not null unique
);

insert into value_type(type_id, name, class_id, width_bits, flags, object_path) values
  (1, 'void', 0, 0, 0, 'kernel/x86_64/object/type/void.erobj'), (2, 'u1', 1, 1, 0, 'kernel/x86_64/object/type/u1.erobj'), (3, 'u8', 1, 8, 0, 'kernel/x86_64/object/type/u8.erobj'), (4, 'u16', 1, 16, 0, 'kernel/x86_64/object/type/u16.erobj'), (5, 'u32', 1, 32, 0, 'kernel/x86_64/object/type/u32.erobj'), (6, 'u64', 1, 64, 0, 'kernel/x86_64/object/type/u64.erobj'), (7, 'u128', 1, 128, 0, 'kernel/x86_64/object/type/u128.erobj'), (8, 'u256', 1, 256, 0, 'kernel/x86_64/object/type/u256.erobj'), (9, 'u512', 1, 512, 0, 'kernel/x86_64/object/type/u512.erobj'), (20, 'i8', 2, 8, 1, 'kernel/x86_64/object/type/i8.erobj'), (21, 'i16', 2, 16, 1, 'kernel/x86_64/object/type/i16.erobj'), (22, 'i32', 2, 32, 1, 'kernel/x86_64/object/type/i32.erobj'), (23, 'i64', 2, 64, 1, 'kernel/x86_64/object/type/i64.erobj'), (24, 'i128', 2, 128, 1, 'kernel/x86_64/object/type/i128.erobj'), (40, 'f16', 3, 16, 0, 'kernel/x86_64/object/type/f16.erobj'), (41, 'f32', 3, 32, 0, 'kernel/x86_64/object/type/f32.erobj'), (42, 'f64', 3, 64, 0, 'kernel/x86_64/object/type/f64.erobj'), (43, 'f80', 3, 80, 0, 'kernel/x86_64/object/type/f80.erobj'), (44, 'f128', 3, 128, 0, 'kernel/x86_64/object/type/f128.erobj'), (60, 'ptr16', 4, 16, 0, 'kernel/x86_64/object/type/ptr16.erobj'), (61, 'ptr32', 4, 32, 0, 'kernel/x86_64/object/type/ptr32.erobj'), (62, 'ptr64', 4, 64, 0, 'kernel/x86_64/object/type/ptr64.erobj'), (70, 'rel8', 5, 8, 0, 'kernel/x86_64/object/type/rel8.erobj'), (71, 'rel16', 5, 16, 0, 'kernel/x86_64/object/type/rel16.erobj'), (72, 'rel32', 5, 32, 0, 'kernel/x86_64/object/type/rel32.erobj'), (73, 'rel64', 5, 64, 0, 'kernel/x86_64/object/type/rel64.erobj'), (100, 'wasm_i32', 6, 32, 0, 'kernel/x86_64/object/type/wasm_i32.erobj'), (101, 'wasm_i64', 6, 64, 0, 'kernel/x86_64/object/type/wasm_i64.erobj'), (102, 'wasm_f32', 6, 32, 0, 'kernel/x86_64/object/type/wasm_f32.erobj'), (103, 'wasm_f64', 6, 64, 0, 'kernel/x86_64/object/type/wasm_f64.erobj'), (104, 'wasm_v128', 6, 128, 0, 'kernel/x86_64/object/type/wasm_v128.erobj'), (105, 'wasm_funcref', 7, 64, 0, 'kernel/x86_64/object/type/wasm_funcref.erobj'), (106, 'wasm_externref', 7, 64, 0, 'kernel/x86_64/object/type/wasm_externref.erobj'), (120, 'flags', 8, 0, 0, 'kernel/x86_64/object/type/flags.erobj'), (121, 'memory', 9, 0, 0, 'kernel/x86_64/object/type/memory.erobj'), (122, 'table', 10, 0, 0, 'kernel/x86_64/object/type/table.erobj'), (123, 'label', 11, 0, 0, 'kernel/x86_64/object/type/label.erobj'), (124, 'import_ref', 12, 0, 0, 'kernel/x86_64/object/type/import_ref.erobj'), (125, 'data_ref', 13, 0, 0, 'kernel/x86_64/object/type/data_ref.erobj');

create table operand_kind_object (
  operand_kind_id integer primary key,
  name text not null unique,
  flags integer not null default 0,
  default_type_id integer references value_type(type_id),
  object_path text not null unique
);

insert into operand_kind_object(operand_kind_id, name, flags, default_type_id, object_path) values
  (1, 'none', 0, 1, 'kernel/x86_64/object/operand_kind/none.erobj'), (2, 'register', 1, null, 'kernel/x86_64/object/operand_kind/register.erobj'), (3, 'immediate', 2, null, 'kernel/x86_64/object/operand_kind/immediate.erobj'), (4, 'memory', 4, 121, 'kernel/x86_64/object/operand_kind/memory.erobj'), (5, 'branch_target', 8, 123, 'kernel/x86_64/object/operand_kind/branch_target.erobj'), (6, 'label', 8, 123, 'kernel/x86_64/object/operand_kind/label.erobj'), (7, 'data_ref', 16, 125, 'kernel/x86_64/object/operand_kind/data_ref.erobj'), (8, 'import_ref', 32, 124, 'kernel/x86_64/object/operand_kind/import_ref.erobj'), (9, 'register_list', 64, null, 'kernel/x86_64/object/operand_kind/register_list.erobj'), (10, 'condition_code', 128, 120, 'kernel/x86_64/object/operand_kind/condition_code.erobj'), (20, 'wasm_local_index', 256, 100, 'kernel/x86_64/object/operand_kind/wasm_local_index.erobj'), (21, 'wasm_global_index', 512, 100, 'kernel/x86_64/object/operand_kind/wasm_global_index.erobj'), (22, 'wasm_table_index', 1024, 100, 'kernel/x86_64/object/operand_kind/wasm_table_index.erobj'), (23, 'wasm_memory_index', 2048, 100, 'kernel/x86_64/object/operand_kind/wasm_memory_index.erobj'), (24, 'wasm_block_type', 4096, 123, 'kernel/x86_64/object/operand_kind/wasm_block_type.erobj'), (25, 'wasm_memarg', 8192, 121, 'kernel/x86_64/object/operand_kind/wasm_memarg.erobj'), (26, 'wasm_value_stack', 16384, null, 'kernel/x86_64/object/operand_kind/wasm_value_stack.erobj');

create table operand_shape (
  shape_id integer primary key,
  name text not null unique,
  operand_count integer not null
);

insert into operand_shape(shape_id, name, operand_count) values
  (1, 'none', 0),
  (2, 'generic_operands', 1),
  (3, 'reg', 1),
  (4, 'reg_reg', 2),
  (5, 'reg_imm', 2),
  (6, 'reg_mem', 2),
  (7, 'mem_reg', 2),
  (8, 'branch_target', 1),
  (9, 'stack_effect', 0),
  (10, 'wasm_value_stack', 0);

create table operand_shape_object (
  shape_id integer primary key,
  name text not null unique,
  operand_count integer not null,
  kind0 integer references operand_kind_object(operand_kind_id),
  kind1 integer references operand_kind_object(operand_kind_id),
  kind2 integer references operand_kind_object(operand_kind_id),
  kind3 integer references operand_kind_object(operand_kind_id),
  flags integer not null default 0,
  object_path text not null unique
);

insert into operand_shape_object(shape_id, name, operand_count, kind0, kind1, kind2, kind3, flags, object_path) values
  (1, 'none', 0, null, null, null, null, 0, 'kernel/x86_64/object/operand_shape/none.erobj'),
  (2, 'reg', 1, 2, null, null, null, 0, 'kernel/x86_64/object/operand_shape/reg.erobj'),
  (3, 'imm', 1, 3, null, null, null, 0, 'kernel/x86_64/object/operand_shape/imm.erobj'),
  (4, 'mem', 1, 4, null, null, null, 0, 'kernel/x86_64/object/operand_shape/mem.erobj'),
  (5, 'reg_reg', 2, 2, 2, null, null, 0, 'kernel/x86_64/object/operand_shape/reg_reg.erobj'),
  (6, 'reg_imm', 2, 2, 3, null, null, 0, 'kernel/x86_64/object/operand_shape/reg_imm.erobj'),
  (7, 'imm_reg', 2, 3, 2, null, null, 0, 'kernel/x86_64/object/operand_shape/imm_reg.erobj'),
  (8, 'reg_mem', 2, 2, 4, null, null, 0, 'kernel/x86_64/object/operand_shape/reg_mem.erobj'),
  (9, 'mem_reg', 2, 4, 2, null, null, 0, 'kernel/x86_64/object/operand_shape/mem_reg.erobj'),
  (10, 'mem_imm', 2, 4, 3, null, null, 0, 'kernel/x86_64/object/operand_shape/mem_imm.erobj'),
  (11, 'branch_target', 1, 5, null, null, null, 1, 'kernel/x86_64/object/operand_shape/branch_target.erobj'),
  (12, 'label', 1, 6, null, null, null, 1, 'kernel/x86_64/object/operand_shape/label.erobj'),
  (13, 'reg_label', 2, 2, 6, null, null, 1, 'kernel/x86_64/object/operand_shape/reg_label.erobj'),
  (14, 'data_ref', 1, 7, null, null, null, 2, 'kernel/x86_64/object/operand_shape/data_ref.erobj'),
  (15, 'import_ref', 1, 8, null, null, null, 4, 'kernel/x86_64/object/operand_shape/import_ref.erobj'),
  (16, 'reg_list', 1, 9, null, null, null, 0, 'kernel/x86_64/object/operand_shape/reg_list.erobj'),
  (17, 'cond_branch', 2, 10, 5, null, null, 1, 'kernel/x86_64/object/operand_shape/cond_branch.erobj'),
  (18, 'reg_reg_imm', 3, 2, 2, 3, null, 0, 'kernel/x86_64/object/operand_shape/reg_reg_imm.erobj'),
  (19, 'reg_mem_imm', 3, 2, 4, 3, null, 0, 'kernel/x86_64/object/operand_shape/reg_mem_imm.erobj'),
  (20, 'mem_reg_imm', 3, 4, 2, 3, null, 0, 'kernel/x86_64/object/operand_shape/mem_reg_imm.erobj'),
  (30, 'wasm_stack', 1, 26, null, null, null, 8, 'kernel/x86_64/object/operand_shape/wasm_stack.erobj'),
  (31, 'wasm_block', 1, 24, null, null, null, 8, 'kernel/x86_64/object/operand_shape/wasm_block.erobj'),
  (32, 'wasm_local', 1, 20, null, null, null, 8, 'kernel/x86_64/object/operand_shape/wasm_local.erobj'),
  (33, 'wasm_global', 1, 21, null, null, null, 8, 'kernel/x86_64/object/operand_shape/wasm_global.erobj'),
  (34, 'wasm_call', 1, 22, null, null, null, 8, 'kernel/x86_64/object/operand_shape/wasm_call.erobj'),
  (35, 'wasm_memarg', 1, 25, null, null, null, 8, 'kernel/x86_64/object/operand_shape/wasm_memarg.erobj'),
  (36, 'wasm_memarg_stack', 2, 25, 26, null, null, 8, 'kernel/x86_64/object/operand_shape/wasm_memarg_stack.erobj'),
  (37, 'wasm_table', 1, 22, null, null, null, 8, 'kernel/x86_64/object/operand_shape/wasm_table.erobj'),
  (38, 'wasm_memory', 1, 23, null, null, null, 8, 'kernel/x86_64/object/operand_shape/wasm_memory.erobj');

create table addressing_mode (
  address_mode_id integer primary key,
  name text not null unique,
  isa_id integer not null references isa(isa_id),
  component_flags integer not null,
  width_bits integer not null,
  scale_mask integer not null,
  displacement_width integer not null,
  immediate_width integer not null,
  flags integer not null default 0,
  object_path text not null unique
);

insert into addressing_mode(address_mode_id, name, isa_id, component_flags, width_bits, scale_mask, displacement_width, immediate_width, flags, object_path) values
  (1, 'x86_64_base', 1, 1, 64, 0, 0, 0, 0, 'kernel/x86_64/object/addressing/x86_64_base.erobj'),
  (2, 'x86_64_base_disp8', 1, 3, 64, 0, 8, 0, 0, 'kernel/x86_64/object/addressing/x86_64_base_disp8.erobj'),
  (3, 'x86_64_base_disp32', 1, 3, 64, 0, 32, 0, 0, 'kernel/x86_64/object/addressing/x86_64_base_disp32.erobj'),
  (4, 'x86_64_base_index', 1, 5, 64, 15, 0, 0, 0, 'kernel/x86_64/object/addressing/x86_64_base_index.erobj'),
  (5, 'x86_64_base_index_disp8', 1, 7, 64, 15, 8, 0, 0, 'kernel/x86_64/object/addressing/x86_64_base_index_disp8.erobj'),
  (6, 'x86_64_base_index_disp32', 1, 7, 64, 15, 32, 0, 0, 'kernel/x86_64/object/addressing/x86_64_base_index_disp32.erobj'),
  (7, 'x86_64_rip_rel32', 1, 8, 64, 0, 32, 0, 1, 'kernel/x86_64/object/addressing/x86_64_rip_rel32.erobj'),
  (8, 'x86_64_abs64', 1, 16, 64, 0, 64, 0, 0, 'kernel/x86_64/object/addressing/x86_64_abs64.erobj'),
  (20, 'x86_32_base', 2, 1, 32, 0, 0, 0, 0, 'kernel/x86_64/object/addressing/x86_32_base.erobj'),
  (21, 'x86_32_base_disp8', 2, 3, 32, 0, 8, 0, 0, 'kernel/x86_64/object/addressing/x86_32_base_disp8.erobj'),
  (22, 'x86_32_base_disp32', 2, 3, 32, 0, 32, 0, 0, 'kernel/x86_64/object/addressing/x86_32_base_disp32.erobj'),
  (23, 'x86_32_base_index', 2, 5, 32, 15, 0, 0, 0, 'kernel/x86_64/object/addressing/x86_32_base_index.erobj'),
  (24, 'x86_32_base_index_disp8', 2, 7, 32, 15, 8, 0, 0, 'kernel/x86_64/object/addressing/x86_32_base_index_disp8.erobj'),
  (25, 'x86_32_base_index_disp32', 2, 7, 32, 15, 32, 0, 0, 'kernel/x86_64/object/addressing/x86_32_base_index_disp32.erobj'),
  (26, 'x86_32_abs32', 2, 16, 32, 0, 32, 0, 0, 'kernel/x86_64/object/addressing/x86_32_abs32.erobj'),
  (40, 'aarch64_base', 3, 1, 64, 0, 0, 0, 0, 'kernel/x86_64/object/addressing/aarch64_base.erobj'),
  (41, 'aarch64_unsigned_offset', 3, 3, 64, 0, 12, 0, 0, 'kernel/x86_64/object/addressing/aarch64_unsigned_offset.erobj'),
  (42, 'aarch64_pre_index', 3, 3, 64, 0, 9, 0, 2, 'kernel/x86_64/object/addressing/aarch64_pre_index.erobj'),
  (43, 'aarch64_post_index', 3, 3, 64, 0, 9, 0, 4, 'kernel/x86_64/object/addressing/aarch64_post_index.erobj'),
  (44, 'aarch64_register_offset', 3, 5, 64, 0, 0, 0, 0, 'kernel/x86_64/object/addressing/aarch64_register_offset.erobj'),
  (45, 'aarch64_literal', 3, 8, 64, 0, 19, 0, 1, 'kernel/x86_64/object/addressing/aarch64_literal.erobj'),
  (60, 'arm32_base', 4, 1, 32, 0, 0, 0, 0, 'kernel/x86_64/object/addressing/arm32_base.erobj'),
  (61, 'arm32_imm12_offset', 4, 3, 32, 0, 12, 0, 0, 'kernel/x86_64/object/addressing/arm32_imm12_offset.erobj'),
  (62, 'arm32_pre_index', 4, 3, 32, 0, 12, 0, 2, 'kernel/x86_64/object/addressing/arm32_pre_index.erobj'),
  (63, 'arm32_post_index', 4, 3, 32, 0, 12, 0, 4, 'kernel/x86_64/object/addressing/arm32_post_index.erobj'),
  (64, 'arm32_register_offset', 4, 5, 32, 0, 0, 0, 0, 'kernel/x86_64/object/addressing/arm32_register_offset.erobj'),
  (65, 'arm32_literal', 4, 8, 32, 0, 12, 0, 1, 'kernel/x86_64/object/addressing/arm32_literal.erobj'),
  (80, 'wasm_memarg', 5, 32, 32, 0, 32, 32, 8, 'kernel/x86_64/object/addressing/wasm_memarg.erobj'),
  (81, 'wasm_memarg64', 5, 32, 64, 0, 64, 64, 8, 'kernel/x86_64/object/addressing/wasm_memarg64.erobj'),
  (82, 'wasm_table_index', 5, 64, 32, 0, 0, 32, 8, 'kernel/x86_64/object/addressing/wasm_table_index.erobj');

create table register_class (
  class_id integer primary key,
  name text not null unique
);

insert into register_class(class_id, name) values
  (1, 'gpr'), (2, 'program_counter'), (3, 'flags'), (4, 'segment'), (5, 'control'), (6, 'debug'), (7, 'x87'), (8, 'mmx'), (9, 'vector'), (10, 'mask'), (20, 'wasm_stack'), (21, 'wasm_index_space'), (22, 'wasm_memory'), (23, 'wasm_table'), (24, 'wasm_value_type'), (25, 'wasm_ref_type');

create table instruction (
  isa_id integer not null references isa(isa_id),
  instruction_id integer not null,
  mnemonic text not null,
  object_path text not null unique,
  primary key (isa_id, instruction_id),
  unique (isa_id, mnemonic)
);

insert or ignore into instruction(isa_id, instruction_id, mnemonic, object_path)
select (select isa_id from isa where name = 'x86_64'),
       row_number() over (order by name),
       replace(replace(name, 'kernel/x86_64/object/instruction/x86_64/', ''), '.erobj', ''),
       name
from fsdir('kernel/x86_64/object/instruction/x86_64')
where data is not null
  and name like '%.erobj';

create table instruction_form (
  isa_id integer not null references isa(isa_id),
  form_id integer not null,
  instruction_id integer not null,
  operand_shape_id integer not null references operand_shape(shape_id),
  encoding_shape_id integer not null,
  flags integer not null default 0,
  input_count integer not null,
  output_count integer not null,
  implicit_count integer not null,
  object_path text not null unique,
  primary key (isa_id, form_id),
  foreign key (isa_id, instruction_id) references instruction(isa_id, instruction_id)
);

create table register_object (
  isa_id integer not null references isa(isa_id),
  register_id integer not null,
  name text not null,
  class_id integer not null references register_class(class_id),
  width_bits integer not null,
  alias_parent_id integer not null default 0,
  flags integer not null default 0,
  object_path text not null unique,
  primary key (isa_id, register_id),
  unique (isa_id, name)
);

create table register_set (
  isa_id integer primary key references isa(isa_id),
  register_count integer not null,
  object_path text not null unique
);

insert into register_set(isa_id, register_count, object_path) values
  (1, 213, 'kernel/x86_64/object/register_set/x86_64.erobj'), (2, 73,  'kernel/x86_64/object/register_set/x86_32.erobj'), (3, 260, 'kernel/x86_64/object/register_set/aarch64.erobj'), (4, 101, 'kernel/x86_64/object/register_set/arm32.erobj'), (5, 13,  'kernel/x86_64/object/register_set/wasm.erobj');

create table concrete_operand (
  operand_id integer primary key,
  name text not null unique,
  operand_kind_id integer not null references operand_kind_object(operand_kind_id),
  type_id integer references value_type(type_id),
  isa_id integer references isa(isa_id),
  register_id integer not null default 0,
  address_mode_id integer references addressing_mode(address_mode_id),
  immediate_value integer not null default 0,
  flags integer not null default 0,
  object_path text not null unique
);

insert into concrete_operand(operand_id, name, operand_kind_id, type_id, isa_id, register_id, address_mode_id, immediate_value, flags, object_path) values
  (1, 'none', 1, 1, null, 0, null, 0, 0, 'kernel/x86_64/object/operand/none.erobj'), (100, 'x86_64_eax', 2, 5, 1, 101, null, 0, 0, 'kernel/x86_64/object/operand/x86_64/eax.erobj'), (101, 'x86_64_rax', 2, 6, 1, 1, null, 0, 0, 'kernel/x86_64/object/operand/x86_64/rax.erobj'), (102, 'x86_64_imm32_42', 3, 5, 1, 0, null, 42, 0, 'kernel/x86_64/object/operand/x86_64/imm32_42.erobj'), (103, 'x86_64_imm32_0', 3, 5, 1, 0, null, 0, 0, 'kernel/x86_64/object/operand/x86_64/imm32_0.erobj'), (200, 'x86_32_eax', 2, 5, 2, 1, null, 0, 0, 'kernel/x86_64/object/operand/x86_32/eax.erobj'), (201, 'x86_32_imm32_42', 3, 5, 2, 0, null, 42, 0, 'kernel/x86_64/object/operand/x86_32/imm32_42.erobj'), (300, 'aarch64_x0', 2, 6, 3, 1, null, 0, 0, 'kernel/x86_64/object/operand/aarch64/x0.erobj'), (301, 'aarch64_x30', 2, 6, 3, 31, null, 0, 0, 'kernel/x86_64/object/operand/aarch64/x30.erobj'), (302, 'aarch64_imm12_0', 3, 5, 3, 0, null, 0, 0, 'kernel/x86_64/object/operand/aarch64/imm12_0.erobj'), (400, 'arm32_r0', 2, 5, 4, 1, null, 0, 0, 'kernel/x86_64/object/operand/arm32/r0.erobj'), (401, 'arm32_lr', 2, 5, 4, 101, null, 0, 0, 'kernel/x86_64/object/operand/arm32/lr.erobj'), (402, 'arm32_imm12_0', 3, 5, 4, 0, null, 0, 0, 'kernel/x86_64/object/operand/arm32/imm12_0.erobj'), (500, 'wasm_none', 1, 1, 5, 0, null, 0, 0, 'kernel/x86_64/object/operand/wasm/none.erobj'), (501, 'wasm_i32_const_42', 3, 100, 5, 0, null, 42, 0, 'kernel/x86_64/object/operand/wasm/i32_const_42.erobj'), (502, 'wasm_local_index_0', 20, 100, 5, 0, null, 0, 0, 'kernel/x86_64/object/operand/wasm/local_index_0.erobj');

create table encoding_pattern (
  encoding_id integer primary key,
  name text not null unique,
  isa_id integer not null references isa(isa_id),
  encoding_kind integer not null,
  fixed_hex text not null,
  immediate_type_id integer references value_type(type_id),
  immediate_operand_index integer not null default -1,
  flags integer not null default 0,
  object_path text not null unique
);

insert into encoding_pattern(encoding_id, name, isa_id, encoding_kind, fixed_hex, immediate_type_id, immediate_operand_index, flags, object_path) values
  (1, 'x86_64_mov_eax_imm32', 1, 1, 'b8', 5, 1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_imm32.erobj'), (2, 'x86_64_ret', 1, 1, 'c3', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/ret.erobj'), (3, 'x86_64_nop', 1, 1, '90', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/nop.erobj'), (82, 'x86_64_mov_rcx_rsi', 1, 1, '4889f1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rcx_rsi.erobj'), (83, 'x86_64_sub_rcx_rdi', 1, 1, '4829f9', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/sub_rcx_rdi.erobj'), (84, 'x86_64_jle_rel8_10', 1, 1, '7e0a', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/jle_rel8_10.erobj'), (85, 'x86_64_xor_eax_eax', 1, 1, '31c0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/xor_eax_eax.erobj'), (86, 'x86_64_cld', 1, 1, 'fc', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cld.erobj'), (87, 'x86_64_shr_rcx_3', 1, 1, '48c1e903', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/shr_rcx_3.erobj'), (88, 'x86_64_rep_stosq', 1, 1, 'f348ab', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/rep_stosq.erobj'), (20, 'x86_32_mov_eax_imm32', 2, 1, 'b8', 5, 1, 0, 'kernel/x86_64/object/encoding/x86_32/mov_eax_imm32.erobj'), (21, 'x86_32_ret', 2, 1, 'c3', null, -1, 0, 'kernel/x86_64/object/encoding/x86_32/ret.erobj'), (40, 'aarch64_ret', 3, 2, 'c0035fd6', null, -1, 0, 'kernel/x86_64/object/encoding/aarch64/ret.erobj'), (41, 'aarch64_nop', 3, 2, '1f2003d5', null, -1, 0, 'kernel/x86_64/object/encoding/aarch64/nop.erobj'), (60, 'arm32_bx_lr', 4, 2, '1eff2fe1', null, -1, 0, 'kernel/x86_64/object/encoding/arm32/bx_lr.erobj'), (61, 'arm32_nop', 4, 2, '00f020e3', null, -1, 0, 'kernel/x86_64/object/encoding/arm32/nop.erobj'), (80, 'wasm_end', 5, 3, '0b', null, -1, 0, 'kernel/x86_64/object/encoding/wasm/end.erobj'), (81, 'wasm_nop', 5, 3, '01', null, -1, 0, 'kernel/x86_64/object/encoding/wasm/nop.erobj');

insert or ignore into encoding_pattern(encoding_id, name, isa_id, encoding_kind, fixed_hex, immediate_type_id, immediate_operand_index, flags, object_path) values
  (1000, 'x86_64_syscall', 1, 1, '0f05', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/syscall.erobj'),
  (1001, 'x86_64_test_eax_eax', 1, 1, '85c0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/test_eax_eax.erobj'),
  (1002, 'x86_64_test_edx_edx', 1, 1, '85d2', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/test_edx_edx.erobj'),
  (1003, 'x86_64_test_rdx_rdx', 1, 1, '4885d2', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/test_rdx_rdx.erobj'),
  (1004, 'x86_64_test_rdi_rdi', 1, 1, '4885ff', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/test_rdi_rdi.erobj'),
  (1005, 'x86_64_test_rax_rax', 1, 1, '4885c0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/test_rax_rax.erobj'),
  (1006, 'x86_64_test_rsi_rsi', 1, 1, '4885f6', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/test_rsi_rsi.erobj'),
  (1007, 'x86_64_xor_edx_edx', 1, 1, '31d2', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/xor_edx_edx.erobj'),
  (1008, 'x86_64_xor_ecx_ecx', 1, 1, '31c9', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/xor_ecx_ecx.erobj'),
  (1009, 'x86_64_xor_esi_esi', 1, 1, '31f6', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/xor_esi_esi.erobj'),
  (1010, 'x86_64_xor_ebx_ebx', 1, 1, '31db', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/xor_ebx_ebx.erobj'),
  (1011, 'x86_64_xor_edi_edi', 1, 1, '31ff', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/xor_edi_edi.erobj'),
  (1012, 'x86_64_xor_r8d_r8d', 1, 1, '4531c0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/xor_r8d_r8d.erobj'),
  (1013, 'x86_64_xor_r9d_r9d', 1, 1, '4531c9', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/xor_r9d_r9d.erobj'),
  (1014, 'x86_64_push_rax', 1, 1, '50', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/push_rax.erobj'),
  (1015, 'x86_64_push_rcx', 1, 1, '51', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/push_rcx.erobj'),
  (1016, 'x86_64_push_rbx', 1, 1, '53', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/push_rbx.erobj'),
  (1017, 'x86_64_push_rbp', 1, 1, '55', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/push_rbp.erobj'),
  (1018, 'x86_64_push_r12', 1, 1, '4154', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/push_r12.erobj'),
  (1019, 'x86_64_push_r13', 1, 1, '4155', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/push_r13.erobj'),
  (1020, 'x86_64_push_r14', 1, 1, '4156', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/push_r14.erobj'),
  (1021, 'x86_64_push_r15', 1, 1, '4157', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/push_r15.erobj'),
  (1022, 'x86_64_pop_rax', 1, 1, '58', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/pop_rax.erobj'),
  (1023, 'x86_64_pop_rcx', 1, 1, '59', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/pop_rcx.erobj'),
  (1024, 'x86_64_pop_rbx', 1, 1, '5b', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/pop_rbx.erobj'),
  (1025, 'x86_64_pop_rbp', 1, 1, '5d', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/pop_rbp.erobj'),
  (1026, 'x86_64_pop_r12', 1, 1, '415c', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/pop_r12.erobj'),
  (1027, 'x86_64_pop_r13', 1, 1, '415d', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/pop_r13.erobj'),
  (1028, 'x86_64_pop_r14', 1, 1, '415e', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/pop_r14.erobj'),
  (1029, 'x86_64_pop_r15', 1, 1, '415f', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/pop_r15.erobj');

insert or ignore into encoding_pattern(encoding_id, name, isa_id, encoding_kind, fixed_hex, immediate_type_id, immediate_operand_index, flags, object_path) values
  (1030, 'x86_64_mov_rdi_r12', 1, 1, '4c89e7', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdi_r12.erobj'),
  (1031, 'x86_64_mov_eax_minus_one', 1, 1, 'b8ffffffff', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_minus_one.erobj'),
  (1032, 'x86_64_mov_r12_rdi', 1, 1, '4989fc', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r12_rdi.erobj'),
  (1033, 'x86_64_mov_rdi_rbx', 1, 1, '4889df', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdi_rbx.erobj'),
  (1034, 'x86_64_mov_eax_1', 1, 1, 'b801000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_1.erobj'),
  (1035, 'x86_64_mov_rsi_r13', 1, 1, '4c89ee', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsi_r13.erobj'),
  (1036, 'x86_64_mov_esi_r13d', 1, 1, '4489ee', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_r13d.erobj'),
  (1037, 'x86_64_mov_eax_ebx', 1, 1, '89d8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_ebx.erobj'),
  (1038, 'x86_64_mov_rdi_rsp', 1, 1, '4889e7', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdi_rsp.erobj'),
  (1039, 'x86_64_mov_rdi_r14', 1, 1, '4c89f7', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdi_r14.erobj'),
  (1040, 'x86_64_mov_rsi_r12', 1, 1, '4c89e6', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsi_r12.erobj'),
  (1041, 'x86_64_mov_rdi_r13', 1, 1, '4c89ef', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdi_r13.erobj'),
  (1042, 'x86_64_mov_edi_r12d', 1, 1, '4489e7', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edi_r12d.erobj'),
  (1043, 'x86_64_mov_r13d_esi', 1, 1, '4189f5', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r13d_esi.erobj'),
  (1044, 'x86_64_mov_rbx_rax', 1, 1, '4889c3', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rbx_rax.erobj'),
  (1045, 'x86_64_mov_esi_eax', 1, 1, '89c6', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_eax.erobj'),
  (1046, 'x86_64_mov_r13_rsi', 1, 1, '4989f5', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r13_rsi.erobj'),
  (1047, 'x86_64_mov_rdx_r14', 1, 1, '4c89f2', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdx_r14.erobj'),
  (1048, 'x86_64_mov_rbx_rdi', 1, 1, '4889fb', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rbx_rdi.erobj'),
  (1049, 'x86_64_mov_eax_r14d', 1, 1, '4489f0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_r14d.erobj'),
  (1050, 'x86_64_mov_rdi_r15', 1, 1, '4c89ff', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdi_r15.erobj'),
  (1051, 'x86_64_mov_r14_rdx', 1, 1, '4989d6', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r14_rdx.erobj'),
  (1052, 'x86_64_mov_ecx_eax', 1, 1, '89c1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ecx_eax.erobj'),
  (1053, 'x86_64_mov_ebx_eax', 1, 1, '89c3', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ebx_eax.erobj'),
  (1054, 'x86_64_mov_eax_ecx', 1, 1, '89c8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_ecx.erobj'),
  (1055, 'x86_64_mov_rsi_r15', 1, 1, '4c89fe', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsi_r15.erobj'),
  (1056, 'x86_64_mov_edi_ebx', 1, 1, '89df', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edi_ebx.erobj'),
  (1057, 'x86_64_mov_edx_ebx', 1, 1, '89da', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edx_ebx.erobj'),
  (1058, 'x86_64_mov_eax_edi', 1, 1, '89f8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_edi.erobj'),
  (1059, 'x86_64_mov_r13_rdx', 1, 1, '4989d5', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r13_rdx.erobj'),
  (1060, 'x86_64_mov_rsi_r14', 1, 1, '4c89f6', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsi_r14.erobj'),
  (1061, 'x86_64_mov_esi_r12d', 1, 1, '4489e6', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_r12d.erobj'),
  (1062, 'x86_64_mov_eax_esi', 1, 1, '89f0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_esi.erobj'),
  (1063, 'x86_64_mov_eax_r13d', 1, 1, '4489e8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_r13d.erobj'),
  (1064, 'x86_64_mov_r14d_edx', 1, 1, '4189d6', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r14d_edx.erobj'),
  (1065, 'x86_64_mov_eax_r15d', 1, 1, '4489f8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_r15d.erobj'),
  (1066, 'x86_64_mov_edi_r14d', 1, 1, '4489f7', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edi_r14d.erobj'),
  (1067, 'x86_64_mov_edx_eax', 1, 1, '89c2', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edx_eax.erobj'),
  (1068, 'x86_64_mov_rdi_rax', 1, 1, '4889c7', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdi_rax.erobj');

insert or ignore into encoding_pattern(encoding_id, name, isa_id, encoding_kind, fixed_hex, immediate_type_id, immediate_operand_index, flags, object_path) values
  (1069, 'x86_64_inc_ecx', 1, 1, 'ffc1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/inc_ecx.erobj'),
  (1070, 'x86_64_inc_ebx', 1, 1, 'ffc3', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/inc_ebx.erobj'),
  (1071, 'x86_64_inc_rbx', 1, 1, '48ffc3', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/inc_rbx.erobj'),
  (1072, 'x86_64_inc_eax', 1, 1, 'ffc0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/inc_eax.erobj'),
  (1073, 'x86_64_inc_rdi', 1, 1, '48ffc7', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/inc_rdi.erobj'),
  (1074, 'x86_64_inc_rax', 1, 1, '48ffc0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/inc_rax.erobj'),
  (1075, 'x86_64_inc_r15d', 1, 1, '41ffc7', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/inc_r15d.erobj'),
  (1076, 'x86_64_inc_r12', 1, 1, '49ffc4', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/inc_r12.erobj'),
  (1077, 'x86_64_inc_r14d', 1, 1, '41ffc6', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/inc_r14d.erobj'),
  (1078, 'x86_64_inc_r8d', 1, 1, '41ffc0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/inc_r8d.erobj'),
  (1079, 'x86_64_inc_r9d', 1, 1, '41ffc1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/inc_r9d.erobj'),
  (1080, 'x86_64_inc_r10', 1, 1, '49ffc2', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/inc_r10.erobj'),
  (1081, 'x86_64_inc_rcx', 1, 1, '48ffc1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/inc_rcx.erobj'),
  (1082, 'x86_64_inc_r10d', 1, 1, '41ffc2', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/inc_r10d.erobj'),
  (1083, 'x86_64_inc_r13', 1, 1, '49ffc5', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/inc_r13.erobj'),
  (1084, 'x86_64_inc_r11d', 1, 1, '41ffc3', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/inc_r11d.erobj'),
  (1085, 'x86_64_inc_edx', 1, 1, 'ffc2', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/inc_edx.erobj'),
  (1086, 'x86_64_inc_r8', 1, 1, '49ffc0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/inc_r8.erobj'),
  (1087, 'x86_64_inc_rsi', 1, 1, '48ffc6', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/inc_rsi.erobj'),
  (1088, 'x86_64_inc_ebp', 1, 1, 'ffc5', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/inc_ebp.erobj'),
  (1089, 'x86_64_inc_r13d', 1, 1, '41ffc5', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/inc_r13d.erobj'),
  (1090, 'x86_64_add_rsp_16', 1, 1, '4883c410', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_rsp_16.erobj'),
  (1091, 'x86_64_add_rsp_8', 1, 1, '4883c408', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_rsp_8.erobj'),
  (1092, 'x86_64_add_eax_ecx', 1, 1, '01c8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_eax_ecx.erobj'),
  (1093, 'x86_64_add_eax_edx', 1, 1, '01d0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_eax_edx.erobj'),
  (1094, 'x86_64_add_ebx_eax', 1, 1, '01c3', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_ebx_eax.erobj'),
  (1095, 'x86_64_add_rsp_24', 1, 1, '4883c418', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_rsp_24.erobj'),
  (1096, 'x86_64_add_rsp_32', 1, 1, '4883c420', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_rsp_32.erobj'),
  (1097, 'x86_64_add_edi_eax', 1, 1, '01c7', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_edi_eax.erobj'),
  (1098, 'x86_64_add_eax_ebx', 1, 1, '01d8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_eax_ebx.erobj'),
  (1099, 'x86_64_add_r15d_eax', 1, 1, '4101c7', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_r15d_eax.erobj'),
  (1100, 'x86_64_add_rax_rcx', 1, 1, '4801c8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_rax_rcx.erobj'),
  (1101, 'x86_64_add_eax_r8d', 1, 1, '4401c0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_eax_r8d.erobj'),
  (1102, 'x86_64_add_rdi_rax', 1, 1, '4801c7', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_rdi_rax.erobj'),
  (1103, 'x86_64_add_rbx_rax', 1, 1, '4801c3', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_rbx_rax.erobj'),
  (1104, 'x86_64_add_edx_eax', 1, 1, '01c2', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_edx_eax.erobj'),
  (1105, 'x86_64_add_edx_ecx', 1, 1, '01ca', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_edx_ecx.erobj');

insert or ignore into encoding_pattern(encoding_id, name, isa_id, encoding_kind, fixed_hex, immediate_type_id, immediate_operand_index, flags, object_path) values
  (1106, 'x86_64_mov_rdi_com1_port', 1, 1, '48c7c7f8030000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdi_com1_port.erobj'),
  (1107, 'x86_64_mov_edi_com1_port', 1, 1, 'bff8030000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edi_com1_port.erobj'),
  (1108, 'x86_64_mov_r12_com1_port', 1, 1, '49c7c4f8030000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r12_com1_port.erobj'),
  (1109, 'x86_64_mov_r14_com1_port', 1, 1, '49c7c6f8030000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r14_com1_port.erobj'),
  (1110, 'x86_64_mov_rsi_com1_port', 1, 1, '48c7c6f8030000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsi_com1_port.erobj'),
  (1111, 'x86_64_mov_rax_rbx_runtime_memory_ptr', 1, 1, '488b03', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rax_rbx_runtime_memory_ptr.erobj'),
  (1112, 'x86_64_cmp_rbx_runtime_ticks_ptr_zero', 1, 1, '48837b1000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_rbx_runtime_ticks_ptr_zero.erobj'),
  (1113, 'x86_64_cmp_rbx_runtime_memory_len_da_app_memory', 1, 1, '48817b0800000100', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_rbx_runtime_memory_len_da_app_memory.erobj'),
  (1114, 'x86_64_mov_rdx_60', 1, 1, '48c7c23c000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdx_60.erobj'),
  (1115, 'x86_64_mov_ecx_32', 1, 1, 'b920000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ecx_32.erobj'),
  (1116, 'x86_64_mov_rdx_48', 1, 1, '48c7c230000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdx_48.erobj'),
  (1117, 'x86_64_mov_ecx_60', 1, 1, 'b93c000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ecx_60.erobj'),
  (1118, 'x86_64_movd_xmm2_eax', 1, 1, '660f6ed0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/movd_xmm2_eax.erobj'),
  (1119, 'x86_64_movd_xmm3_eax', 1, 1, '660f6ed8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/movd_xmm3_eax.erobj'),
  (1120, 'x86_64_pxor_xmm0_xmm0', 1, 1, '660fefc0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/pxor_xmm0_xmm0.erobj'),
  (1121, 'x86_64_mov_eax_0x3f800000', 1, 1, 'b80000803f', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_0x3f800000.erobj'),
  (1122, 'x86_64_mov_r9d_minus_one', 1, 1, '41b9ffffffff', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r9d_minus_one.erobj'),
  (1123, 'x86_64_pxor_xmm1_xmm1', 1, 1, '660fefc9', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/pxor_xmm1_xmm1.erobj'),
  (1124, 'x86_64_mov_ecx_4', 1, 1, 'b904000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ecx_4.erobj'),
  (1125, 'x86_64_mov_ecx_36', 1, 1, 'b924000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ecx_36.erobj'),
  (1126, 'x86_64_mov_edx_minus_one', 1, 1, 'baffffffff', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edx_minus_one.erobj'),
  (1127, 'x86_64_mov_esi_1', 1, 1, 'be01000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_1.erobj'),
  (1128, 'x86_64_mov_r8d_minus_one', 1, 1, '41b8ffffffff', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r8d_minus_one.erobj'),
  (1129, 'x86_64_mov_rdx_1', 1, 1, '48c7c201000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdx_1.erobj'),
  (1130, 'x86_64_mov_rdx_9', 1, 1, '48c7c209000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdx_9.erobj'),
  (1131, 'x86_64_mov_rdx_36', 1, 1, '48c7c224000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdx_36.erobj'),
  (1132, 'x86_64_mov_rdx_15', 1, 1, '48c7c20f000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdx_15.erobj'),
  (1133, 'x86_64_mov_rdx_8', 1, 1, '48c7c208000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdx_8.erobj'),
  (1134, 'x86_64_mov_rdx_32', 1, 1, '48c7c220000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdx_32.erobj'),
  (1135, 'x86_64_movd_eax_xmm0', 1, 1, '660f7ec0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/movd_eax_xmm0.erobj'),
  (1136, 'x86_64_mov_eax_0x3e800000', 1, 1, 'b80000803e', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_0x3e800000.erobj'),
  (1137, 'x86_64_mov_eax_0x3f400000', 1, 1, 'b80000403f', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_0x3f400000.erobj'),
  (1138, 'x86_64_mov_eax_0x41800000', 1, 1, 'b800008041', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_0x41800000.erobj'),
  (1139, 'x86_64_mov_eax_0x42000000', 1, 1, 'b800000042', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_0x42000000.erobj'),
  (1140, 'x86_64_mov_ecx_minus_one', 1, 1, 'b9ffffffff', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ecx_minus_one.erobj'),
  (1141, 'x86_64_mov_edi_0', 1, 1, 'bf00000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edi_0.erobj'),
  (1142, 'x86_64_mov_edi_255', 1, 1, 'bfff000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edi_255.erobj'),
  (1143, 'x86_64_mov_edi_7', 1, 1, 'bf07000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edi_7.erobj'),
  (1144, 'x86_64_mov_edx_minus_two', 1, 1, 'bafeffffff', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edx_minus_two.erobj'),
  (1145, 'x86_64_mov_edx_255', 1, 1, 'baff000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edx_255.erobj'),
  (1146, 'x86_64_mov_esi_2', 1, 1, 'be02000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_2.erobj'),
  (1147, 'x86_64_mov_esi_5', 1, 1, 'be05000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_5.erobj'),
  (1148, 'x86_64_mov_r9d_42', 1, 1, '41b92a000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r9d_42.erobj'),
  (1149, 'x86_64_mov_rdx_minus_two', 1, 1, '48c7c2feffffff', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdx_minus_two.erobj'),
  (1150, 'x86_64_mov_rdx_4', 1, 1, '48c7c204000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdx_4.erobj'),
  (1151, 'x86_64_movd_xmm0_eax', 1, 1, '660f6ec0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/movd_xmm0_eax.erobj'),
  (1152, 'x86_64_movd_xmm1_eax', 1, 1, '660f6ec8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/movd_xmm1_eax.erobj');

insert or ignore into encoding_pattern(encoding_id, name, isa_id, encoding_kind, fixed_hex, immediate_type_id, immediate_operand_index, flags, object_path) values
  (1153, 'x86_64_dec_ecx', 1, 1, 'ffc9', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/dec_ecx.erobj'),
  (1154, 'x86_64_dec_eax', 1, 1, 'ffc8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/dec_eax.erobj');

insert or ignore into encoding_pattern(encoding_id, name, isa_id, encoding_kind, fixed_hex, immediate_type_id, immediate_operand_index, flags, object_path) values
  (1155, 'x86_64_mov_edx_unexpected_ntor_stub_exit', 1, 1, 'ba58000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edx_unexpected_ntor_stub_exit.erobj');

insert or ignore into encoding_pattern(encoding_id, name, isa_id, encoding_kind, fixed_hex, immediate_type_id, immediate_operand_index, flags, object_path) values
  (1156, 'x86_64_mov_edx_1', 1, 1, 'ba01000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edx_1.erobj'),
  (1157, 'x86_64_mov_ecx_1', 1, 1, 'b901000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ecx_1.erobj'),
  (1158, 'x86_64_mov_edi_1', 1, 1, 'bf01000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edi_1.erobj'),
  (1159, 'x86_64_mov_r12d_edi', 1, 1, '4189fc', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r12d_edi.erobj'),
  (1160, 'x86_64_mov_rbp_rsp', 1, 1, '4889e5', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rbp_rsp.erobj'),
  (1161, 'x86_64_mov_r12_rsi', 1, 1, '4989f4', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r12_rsi.erobj'),
  (1162, 'x86_64_cmp_eax_1', 1, 1, '83f801', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_eax_1.erobj'),
  (1163, 'x86_64_mov_r15_rcx', 1, 1, '4989cf', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r15_rcx.erobj'),
  (1164, 'x86_64_mov_r15d_ecx', 1, 1, '4189cf', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r15d_ecx.erobj'),
  (1165, 'x86_64_mov_eax_r11d', 1, 1, '4489d8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_r11d.erobj'),
  (1166, 'x86_64_mov_edx_2', 1, 1, 'ba02000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edx_2.erobj'),
  (1167, 'x86_64_mov_edx_32', 1, 1, 'ba20000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edx_32.erobj'),
  (1168, 'x86_64_mov_rax_rdi', 1, 1, '4889f8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rax_rdi.erobj'),
  (1169, 'x86_64_xor_r15d_r15d', 1, 1, '4531ff', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/xor_r15d_r15d.erobj'),
  (1170, 'x86_64_mov_rdx_r13', 1, 1, '4c89ea', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdx_r13.erobj'),
  (1171, 'x86_64_mov_esi_ebx', 1, 1, '89de', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_ebx.erobj'),
  (1172, 'x86_64_xor_r10d_r10d', 1, 1, '4531d2', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/xor_r10d_r10d.erobj'),
  (1173, 'x86_64_or_eax_ecx', 1, 1, '09c8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/or_eax_ecx.erobj'),
  (1174, 'x86_64_mov_edx_r14d', 1, 1, '4489f2', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edx_r14d.erobj'),
  (1175, 'x86_64_mov_esi_r14d', 1, 1, '4489f6', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_r14d.erobj'),
  (1176, 'x86_64_mov_ebx_edx', 1, 1, '89d3', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ebx_edx.erobj'),
  (1177, 'x86_64_mov_r14_rcx', 1, 1, '4989ce', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r14_rcx.erobj'),
  (1178, 'x86_64_xor_r14d_r14d', 1, 1, '4531f6', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/xor_r14d_r14d.erobj'),
  (1179, 'x86_64_mov_eax_edx', 1, 1, '89d0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_edx.erobj'),
  (1180, 'x86_64_mov_ebx_esi', 1, 1, '89f3', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ebx_esi.erobj'),
  (1181, 'x86_64_mov_r14d_eax', 1, 1, '4189c6', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r14d_eax.erobj'),
  (1182, 'x86_64_mov_eax_r8d', 1, 1, '4489c0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_r8d.erobj'),
  (1183, 'x86_64_mov_rdi_ptr_al', 1, 1, '8807', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdi_ptr_al.erobj'),
  (1184, 'x86_64_xor_r11d_r11d', 1, 1, '4531db', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/xor_r11d_r11d.erobj'),
  (1185, 'x86_64_mov_r8d_eax', 1, 1, '4189c0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r8d_eax.erobj'),
  (1186, 'x86_64_mov_r13d_edx', 1, 1, '4189d5', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r13d_edx.erobj'),
  (1187, 'x86_64_mov_ecx_r15d', 1, 1, '4489f9', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ecx_r15d.erobj'),
  (1188, 'x86_64_mov_ecx_ebx', 1, 1, '89d9', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ecx_ebx.erobj'),
  (1189, 'x86_64_mov_edx_r13d', 1, 1, '4489ea', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edx_r13d.erobj'),
  (1190, 'x86_64_mov_r8d_1', 1, 1, '41b801000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r8d_1.erobj'),
  (1191, 'x86_64_or_eax_edx', 1, 1, '09d0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/or_eax_edx.erobj'),
  (1192, 'x86_64_mov_ecx_r14d', 1, 1, '4489f1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ecx_r14d.erobj'),
  (1193, 'x86_64_mov_r12_rdx', 1, 1, '4989d4', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r12_rdx.erobj'),
  (1194, 'x86_64_mov_r15d_eax', 1, 1, '4189c7', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r15d_eax.erobj'),
  (1195, 'x86_64_mov_r15_r8', 1, 1, '4d89c7', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r15_r8.erobj'),
  (1196, 'x86_64_mov_edx_r15d', 1, 1, '4489fa', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edx_r15d.erobj'),
  (1197, 'x86_64_cmp_eax_2', 1, 1, '83f802', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_eax_2.erobj'),
  (1198, 'x86_64_mov_rdx_r15', 1, 1, '4c89fa', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdx_r15.erobj'),
  (1199, 'x86_64_test_ecx_ecx', 1, 1, '85c9', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/test_ecx_ecx.erobj'),
  (1200, 'x86_64_cmp_eax_ecx', 1, 1, '39c8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_eax_ecx.erobj'),
  (1201, 'x86_64_div_ecx', 1, 1, 'f7f1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/div_ecx.erobj'),
  (1202, 'x86_64_mov_r13_rcx', 1, 1, '4989cd', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r13_rcx.erobj'),
  (1203, 'x86_64_mov_rbx_r8', 1, 1, '4c89c3', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rbx_r8.erobj'),
  (1204, 'x86_64_mov_rcx_r15', 1, 1, '4c89f9', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rcx_r15.erobj'),
  (1205, 'x86_64_mov_rdx_rsp', 1, 1, '4889e2', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdx_rsp.erobj'),
  (1206, 'x86_64_mov_edi_eax', 1, 1, '89c7', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edi_eax.erobj'),
  (1207, 'x86_64_mov_r12d_esi', 1, 1, '4189f4', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r12d_esi.erobj'),
  (1208, 'x86_64_mov_esi_3', 1, 1, 'be03000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_3.erobj'),
  (1209, 'x86_64_mov_ecx_2', 1, 1, 'b902000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ecx_2.erobj'),
  (1210, 'x86_64_test_r14d_r14d', 1, 1, '4585f6', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/test_r14d_r14d.erobj'),
  (1211, 'x86_64_mov_r12d_eax', 1, 1, '4189c4', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r12d_eax.erobj'),
  (1212, 'x86_64_mov_ebx_1', 1, 1, 'bb01000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ebx_1.erobj'),
  (1213, 'x86_64_mov_edx_r8d', 1, 1, '4489c2', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edx_r8d.erobj'),
  (1214, 'x86_64_cmp_eax_r13d', 1, 1, '4439e8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_eax_r13d.erobj'),
  (1215, 'x86_64_mov_r10d_eax', 1, 1, '4189c2', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r10d_eax.erobj'),
  (1216, 'x86_64_test_r15d_r15d', 1, 1, '4585ff', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/test_r15d_r15d.erobj'),
  (1217, 'x86_64_mov_r15d_r8d', 1, 1, '4589c7', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r15d_r8d.erobj'),
  (1218, 'x86_64_xor_r12d_r12d', 1, 1, '4531e4', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/xor_r12d_r12d.erobj'),
  (1219, 'x86_64_mov_r11d_eax', 1, 1, '4189c3', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r11d_eax.erobj'),
  (1220, 'x86_64_mov_r15_rax', 1, 1, '4989c7', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r15_rax.erobj'),
  (1221, 'x86_64_add_rsp_48', 1, 1, '4883c430', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_rsp_48.erobj'),
  (1222, 'x86_64_sub_eax_ebx', 1, 1, '29d8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/sub_eax_ebx.erobj'),
  (1223, 'x86_64_shl_eax_cl', 1, 1, 'd3e0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/shl_eax_cl.erobj'),
  (1224, 'x86_64_mov_ebx_edi', 1, 1, '89fb', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ebx_edi.erobj'),
  (1225, 'x86_64_xor_r13d_r13d', 1, 1, '4531ed', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/xor_r13d_r13d.erobj'),
  (1226, 'x86_64_sub_rsp_16', 1, 1, '4883ec10', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/sub_rsp_16.erobj'),
  (1227, 'x86_64_shr_eax_8', 1, 1, 'c1e808', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/shr_eax_8.erobj'),
  (1228, 'x86_64_mov_eax_r12d', 1, 1, '4489e0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_r12d.erobj'),
  (1229, 'x86_64_rep_movsb', 1, 1, 'f3a4', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/rep_movsb.erobj'),
  (1230, 'x86_64_push_rdi', 1, 1, '57', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/push_rdi.erobj'),
  (1231, 'x86_64_mov_rsi_rax', 1, 1, '4889c6', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsi_rax.erobj'),
  (1232, 'x86_64_mov_edx_ecx', 1, 1, '89ca', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edx_ecx.erobj'),
  (1233, 'x86_64_mov_r14d_ecx', 1, 1, '4189ce', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r14d_ecx.erobj'),
  (1234, 'x86_64_pop_rdi', 1, 1, '5f', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/pop_rdi.erobj'),
  (1235, 'x86_64_shl_eax_2', 1, 1, 'c1e002', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/shl_eax_2.erobj'),
  (1236, 'x86_64_mov_rsi_rdi', 1, 1, '4889fe', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsi_rdi.erobj'),
  (1237, 'x86_64_shl_eax_1', 1, 1, 'd1e0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/shl_eax_1.erobj'),
  (1238, 'x86_64_mov_eax_r9d', 1, 1, '4489c8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_r9d.erobj'),
  (1239, 'x86_64_cmp_eax_ebx', 1, 1, '39d8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_eax_ebx.erobj'),
  (1240, 'x86_64_mov_rdi_rdx', 1, 1, '4889d7', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdi_rdx.erobj'),
  (1241, 'x86_64_cmp_eax_r14d', 1, 1, '4439f0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_eax_r14d.erobj'),
  (1242, 'x86_64_mov_rdx_rsi', 1, 1, '4889f2', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdx_rsi.erobj'),
  (1243, 'x86_64_test_r8d_r8d', 1, 1, '4585c0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/test_r8d_r8d.erobj'),
  (1244, 'x86_64_movzx_eax_byte_rdi_ptr', 1, 1, '0fb607', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/movzx_eax_byte_rdi_ptr.erobj'),
  (1245, 'x86_64_mov_rsi_rbx', 1, 1, '4889de', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsi_rbx.erobj'),
  (1246, 'x86_64_sub_eax_ecx', 1, 1, '29c8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/sub_eax_ecx.erobj'),
  (1247, 'x86_64_dec_r14d', 1, 1, '41ffce', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/dec_r14d.erobj'),
  (1248, 'x86_64_shr_eax_3', 1, 1, 'c1e803', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/shr_eax_3.erobj'),
  (1249, 'x86_64_mov_ebx_r8d', 1, 1, '4489c3', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ebx_r8d.erobj'),
  (1250, 'x86_64_mov_esi_r15d', 1, 1, '4489fe', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_r15d.erobj'),
  (1251, 'x86_64_shl_eax_3', 1, 1, 'c1e003', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/shl_eax_3.erobj'),
  (1252, 'x86_64_mov_rdx_r12', 1, 1, '4c89e2', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdx_r12.erobj'),
  (1253, 'x86_64_cmp_eax_r12d', 1, 1, '4439e0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_eax_r12d.erobj'),
  (1254, 'x86_64_add_eax_r13d', 1, 1, '4401e8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_eax_r13d.erobj'),
  (1255, 'x86_64_mov_r9d_eax', 1, 1, '4189c1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r9d_eax.erobj'),
  (1256, 'x86_64_mov_al_rdi_ptr', 1, 1, '8a07', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_al_rdi_ptr.erobj'),
  (1257, 'x86_64_mov_edx_3', 1, 1, 'ba03000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edx_3.erobj'),
  (1258, 'x86_64_lea_rdi_r12_rax', 1, 1, '498d3c04', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/lea_rdi_r12_rax.erobj'),
  (1259, 'x86_64_inc_r12d', 1, 1, '41ffc4', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/inc_r12d.erobj'),
  (1260, 'x86_64_mov_r15d_edx', 1, 1, '4189d7', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r15d_edx.erobj'),
  (1261, 'x86_64_dec_r13d', 1, 1, '41ffcd', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/dec_r13d.erobj'),
  (1262, 'x86_64_mov_rsp_24_rax', 1, 1, '4889442418', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsp_24_rax.erobj'),
  (1263, 'x86_64_push_r10', 1, 1, '4152', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/push_r10.erobj'),
  (1264, 'x86_64_cmp_eax_esi', 1, 1, '39f0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_eax_esi.erobj'),
  (1265, 'x86_64_add_eax_r15d', 1, 1, '4401f8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_eax_r15d.erobj'),
  (1266, 'x86_64_cmp_eax_edx', 1, 1, '39d0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_eax_edx.erobj'),
  (1267, 'x86_64_mov_r14_r8', 1, 1, '4d89c6', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r14_r8.erobj'),
  (1268, 'x86_64_cmp_eax_0', 1, 1, '83f800', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_eax_0.erobj'),
  (1269, 'x86_64_shl_eax_16', 1, 1, 'c1e010', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/shl_eax_16.erobj'),
  (1270, 'x86_64_mov_r12_rax', 1, 1, '4989c4', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r12_rax.erobj'),
  (1271, 'x86_64_mov_edx_16', 1, 1, 'ba10000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edx_16.erobj'),
  (1272, 'x86_64_mov_cl_1', 1, 1, 'b101', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_cl_1.erobj'),
  (1273, 'x86_64_mov_r14_rax', 1, 1, '4989c6', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r14_rax.erobj'),
  (1274, 'x86_64_in_al_dx', 1, 1, 'ec', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/in_al_dx.erobj'),
  (1275, 'x86_64_out_dx_al', 1, 1, 'ee', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/out_dx_al.erobj'),
  (1276, 'x86_64_pop_rdx', 1, 1, '5a', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/pop_rdx.erobj'),
  (1277, 'x86_64_pop_rsi', 1, 1, '5e', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/pop_rsi.erobj'),
  (1278, 'x86_64_push_rdx', 1, 1, '52', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/push_rdx.erobj'),
  (1279, 'x86_64_push_r8', 1, 1, '4150', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/push_r8.erobj'),
  (1280, 'x86_64_push_rsi', 1, 1, '56', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/push_rsi.erobj'),
  (1281, 'x86_64_movzx_eax_al', 1, 1, '0fb6c0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/movzx_eax_al.erobj'),
  (1282, 'x86_64_shr_eax_16', 1, 1, 'c1e810', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/shr_eax_16.erobj'),
  (1283, 'x86_64_cmp_eax_0xffffffff', 1, 1, '3dffffffff', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_eax_0xffffffff.erobj'),
  (1284, 'x86_64_pop_r8', 1, 1, '4158', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/pop_r8.erobj'),
  (1285, 'x86_64_mov_rdx_rax', 1, 1, '4889c2', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdx_rax.erobj'),
  (1286, 'x86_64_sub_rsp_8', 1, 1, '4883ec08', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/sub_rsp_8.erobj'),
  (1287, 'x86_64_mov_ecx_8', 1, 1, 'b908000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ecx_8.erobj'),
  (1288, 'x86_64_mov_r13d_eax', 1, 1, '4189c5', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r13d_eax.erobj'),
  (1289, 'x86_64_rep_stosb', 1, 1, 'f3aa', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/rep_stosb.erobj'),
  (1290, 'x86_64_mov_rdx_rbx', 1, 1, '4889da', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdx_rbx.erobj'),
  (1291, 'x86_64_mov_edi_2', 1, 1, 'bf02000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edi_2.erobj'),
  (1292, 'x86_64_push_r9', 1, 1, '4151', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/push_r9.erobj'),
  (1293, 'x86_64_mov_ecx_16', 1, 1, 'b910000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ecx_16.erobj'),
  (1294, 'x86_64_mov_ecx_3', 1, 1, 'b903000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ecx_3.erobj'),
  (1295, 'x86_64_sub_rsp_32', 1, 1, '4883ec20', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/sub_rsp_32.erobj'),
  (1296, 'x86_64_mov_eax_r10d', 1, 1, '4489d0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_r10d.erobj'),
  (1297, 'x86_64_mov_rsi_rsp', 1, 1, '4889e6', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsi_rsp.erobj'),
  (1298, 'x86_64_mov_rdi_rsi', 1, 1, '4889f7', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdi_rsi.erobj'),
  (1299, 'x86_64_mov_r8_rdi', 1, 1, '4989f8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r8_rdi.erobj'),
  (1300, 'x86_64_mov_ecx_esi', 1, 1, '89f1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ecx_esi.erobj'),
  (1301, 'arm32_mov_r0_0', 4, 1, '0000a0e3', null, -1, 0, 'kernel/x86_64/object/encoding/arm32/mov_r0_0.erobj'),
  (1302, 'arm32_cmp_r0_0', 4, 1, '000050e3', null, -1, 0, 'kernel/x86_64/object/encoding/arm32/cmp_r0_0.erobj'),
  (1304, 'arm32_pop_pc', 4, 1, '04f09de4', null, -1, 0, 'kernel/x86_64/object/encoding/arm32/pop_pc.erobj'),
  (1305, 'arm32_push_lr', 4, 1, '04e02de5', null, -1, 0, 'kernel/x86_64/object/encoding/arm32/push_lr.erobj'),
  (1306, 'arm32_mov_r1_0', 4, 1, '0010a0e3', null, -1, 0, 'kernel/x86_64/object/encoding/arm32/mov_r1_0.erobj'),
  (1307, 'arm32_pop_r4_pc', 4, 1, '1080bde8', null, -1, 0, 'kernel/x86_64/object/encoding/arm32/pop_r4_pc.erobj'),
  (1308, 'arm32_push_r4_lr', 4, 1, '10402de9', null, -1, 0, 'kernel/x86_64/object/encoding/arm32/push_r4_lr.erobj'),
  (1309, 'arm32_mov_r0_1', 4, 1, '0100a0e3', null, -1, 0, 'kernel/x86_64/object/encoding/arm32/mov_r0_1.erobj'),
  (1310, 'x86_64_mov_esi_4', 1, 1, 'be04000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_4.erobj'),
  (1311, 'x86_64_mov_rax_r12', 1, 1, '4c89e0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rax_r12.erobj'),
  (1312, 'x86_64_mov_r8_rax', 1, 1, '4989c0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r8_rax.erobj'),
  (1313, 'x86_64_mov_rbx_rsi', 1, 1, '4889f3', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rbx_rsi.erobj'),
  (1315, 'x86_64_cmp_ebx_r13d', 1, 1, '4439eb', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_ebx_r13d.erobj'),
  (1316, 'x86_64_cmp_eax_3', 1, 1, '83f803', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_eax_3.erobj'),
  (1317, 'x86_64_mov_edx_64', 1, 1, 'ba40000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edx_64.erobj'),
  (1318, 'x86_64_mov_rbx_rdx', 1, 1, '4889d3', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rbx_rdx.erobj'),
  (1319, 'x86_64_mov_rax_r13', 1, 1, '4c89e8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rax_r13.erobj'),
  (1320, 'x86_64_dec_ebx', 1, 1, 'ffcb', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/dec_ebx.erobj'),
  (1321, 'x86_64_pop_r9', 1, 1, '4159', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/pop_r9.erobj'),
  (1322, 'x86_64_mov_ecx_64', 1, 1, 'b940000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ecx_64.erobj'),
  (1323, 'x86_64_mov_rcx_r14', 1, 1, '4c89f1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rcx_r14.erobj'),
  (1324, 'x86_64_mov_edi_r13d', 1, 1, '4489ef', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edi_r13d.erobj'),
  (1325, 'x86_64_pop_r10', 1, 1, '415a', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/pop_r10.erobj'),
  (1326, 'x86_64_mov_rdi_ptr_eax', 1, 1, '8907', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdi_ptr_eax.erobj'),
  (1327, 'x86_64_mov_rdi_ptr_rax', 1, 1, '488907', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdi_ptr_rax.erobj'),
  (1328, 'x86_64_dec_rcx', 1, 1, '48ffc9', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/dec_rcx.erobj'),
  (1329, 'x86_64_mov_rcx_r13', 1, 1, '4c89e9', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rcx_r13.erobj'),
  (1330, 'x86_64_mov_ecx_r8d', 1, 1, '4489c1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ecx_r8d.erobj'),
  (1331, 'x86_64_lea_rdi_rsp', 1, 1, '488d3c24', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/lea_rdi_rsp.erobj'),
  (1332, 'x86_64_sub_rsp_64', 1, 1, '4883ec40', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/sub_rsp_64.erobj'),
  (1333, 'x86_64_mov_rax_r15', 1, 1, '4c89f8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rax_r15.erobj'),
  (1334, 'x86_64_cmp_edx_error_no_data', 1, 1, '83fa17', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_edx_error_no_data.erobj'),
  (1335, 'x86_64_mov_r8d_edx', 1, 1, '4189d0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r8d_edx.erobj'),
  (1336, 'x86_64_cmp_edx_error_unsupported', 1, 1, '83fa01', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_edx_error_unsupported.erobj'),
  (1337, 'x86_64_cmp_edx_error_corrupt', 1, 1, '83fa02', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_edx_error_corrupt.erobj'),
  (1338, 'x86_64_dec_r15d', 1, 1, '41ffcf', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/dec_r15d.erobj'),
  (1339, 'x86_64_cmp_rax_rcx', 1, 1, '4839c8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_rax_rcx.erobj'),
  (1340, 'x86_64_mov_rdi_ptr_byte_0', 1, 1, 'c60700', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdi_ptr_byte_0.erobj'),
  (1341, 'x86_64_mov_rax_r8', 1, 1, '4c89c0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rax_r8.erobj'),
  (1342, 'x86_64_add_dl_ascii_0', 1, 1, '80c230', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_dl_ascii_0.erobj'),
  (1343, 'x86_64_mov_r13_rax', 1, 1, '4989c5', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r13_rax.erobj'),
  (1344, 'x86_64_test_al_al', 1, 1, '84c0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/test_al_al.erobj'),
  (1345, 'x86_64_mov_rax_r11', 1, 1, '4c89d8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rax_r11.erobj'),
  (1346, 'x86_64_xor_rdx_rdx', 1, 1, '4831d2', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/xor_rdx_rdx.erobj'),
  (1347, 'x86_64_mov_rcx_rdx', 1, 1, '4889d1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rcx_rdx.erobj'),
  (1348, 'x86_64_cmp_rax_rdx', 1, 1, '4839d0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_rax_rdx.erobj'),
  (1349, 'x86_64_add_eax_r14d', 1, 1, '4401f0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_eax_r14d.erobj'),
  (1350, 'x86_64_mov_edi_r15d', 1, 1, '4489ff', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edi_r15d.erobj'),
  (1351, 'x86_64_mov_ebx_ecx', 1, 1, '89cb', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ebx_ecx.erobj'),
  (1352, 'x86_64_dec_edx', 1, 1, 'ffca', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/dec_edx.erobj'),
  (1353, 'x86_64_mov_edx_4', 1, 1, 'ba04000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edx_4.erobj'),
  (1354, 'x86_64_shl_eax_8', 1, 1, 'c1e008', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/shl_eax_8.erobj'),
  (1355, 'x86_64_add_rsp_64', 1, 1, '4883c440', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_rsp_64.erobj'),
  (1356, 'x86_64_test_r15_r15', 1, 1, '4d85ff', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/test_r15_r15.erobj'),
  (1357, 'x86_64_cmp_eax_4', 1, 1, '83f804', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_eax_4.erobj'),
  (1358, 'x86_64_mov_edx_r9d', 1, 1, '4489ca', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edx_r9d.erobj'),
  (1359, 'x86_64_mov_al_rsi_ptr', 1, 1, '8a06', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_al_rsi_ptr.erobj'),
  (1360, 'x86_64_dec_rax', 1, 1, '48ffc8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/dec_rax.erobj'),
  (1361, 'x86_64_mov_rax_minus_1', 1, 1, '48c7c0ffffffff', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rax_minus_1.erobj'),
  (1362, 'x86_64_pause', 1, 1, 'f390', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/pause.erobj'),
  (1363, 'x86_64_mov_esi_edx', 1, 1, '89d6', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_edx.erobj'),
  (1364, 'x86_64_shl_ecx_3', 1, 1, 'c1e103', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/shl_ecx_3.erobj'),
  (1365, 'x86_64_mov_eax_rsp_ptr', 1, 1, '8b0424', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_rsp_ptr.erobj'),
  (1366, 'x86_64_mov_rax_rsp_ptr', 1, 1, '488b0424', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rax_rsp_ptr.erobj'),
  (1367, 'x86_64_pop_r11', 1, 1, '415b', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/pop_r11.erobj'),
  (1368, 'x86_64_mov_r13d_ecx', 1, 1, '4189cd', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r13d_ecx.erobj'),
  (1369, 'x86_64_inc_r15', 1, 1, '49ffc7', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/inc_r15.erobj'),
  (1370, 'x86_64_mov_rcx_rax', 1, 1, '4889c1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rcx_rax.erobj'),
  (1371, 'x86_64_mov_esi_7', 1, 1, 'be07000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_7.erobj'),
  (1372, 'x86_64_cmp_al_10', 1, 1, '3c0a', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_al_10.erobj'),
  (1373, 'x86_64_mov_esi_8', 1, 1, 'be08000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_8.erobj'),
  (1374, 'x86_64_mov_rax_rbx', 1, 1, '4889d8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rax_rbx.erobj'),
  (1375, 'x86_64_mul_ecx', 1, 1, 'f7e1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mul_ecx.erobj'),
  (1376, 'x86_64_bswap_eax', 1, 1, '0fc8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/bswap_eax.erobj'),
  (1377, 'x86_64_inc_r11', 1, 1, '49ffc3', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/inc_r11.erobj'),
  (1378, 'x86_64_mov_r10_rax', 1, 1, '4989c2', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r10_rax.erobj'),
  (1379, 'x86_64_cmp_ecx_esi', 1, 1, '39f1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_ecx_esi.erobj'),
  (1380, 'x86_64_mov_rax_rsi', 1, 1, '4889f0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rax_rsi.erobj'),
  (1381, 'x86_64_dec_rbx', 1, 1, '48ffcb', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/dec_rbx.erobj'),
  (1382, 'x86_64_mov_esi_16', 1, 1, 'be10000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_16.erobj'),
  (1383, 'x86_64_mov_rsi_r9', 1, 1, '4c89ce', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsi_r9.erobj');

insert or ignore into encoding_pattern(encoding_id, name, isa_id, encoding_kind, fixed_hex, immediate_type_id, immediate_operand_index, flags, object_path) values
  (1384, 'x86_64_cmp_rdx_error_recursion', 1, 1, '4883fa1f', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_rdx_error_recursion.erobj'),
  (1385, 'x86_64_mov_eax_sys_write', 1, 1, 'b801000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_sys_write.erobj'),
  (1386, 'x86_64_mov_eax_sys_close', 1, 1, 'b803000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_sys_close.erobj'),
  (1387, 'x86_64_mov_rsi_rdx', 1, 1, '4889d6', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsi_rdx.erobj'),
  (1388, 'x86_64_mov_esi_32', 1, 1, 'be20000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_32.erobj'),
  (1389, 'x86_64_mov_r12_rsp_ptr', 1, 1, '4c8b2424', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r12_rsp_ptr.erobj'),
  (1390, 'x86_64_shr_eax_24', 1, 1, 'c1e818', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/shr_eax_24.erobj'),
  (1391, 'x86_64_add_r15_rax', 1, 1, '4901c7', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_r15_rax.erobj'),
  (1392, 'x86_64_test_r13d_r13d', 1, 1, '4585ed', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/test_r13d_r13d.erobj'),
  (1393, 'x86_64_sub_ecx_eax', 1, 1, '29c1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/sub_ecx_eax.erobj'),
  (1394, 'x86_64_mov_rsp_ptr_eax', 1, 1, '890424', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsp_ptr_eax.erobj'),
  (1395, 'x86_64_test_ebx_ebx', 1, 1, '85db', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/test_ebx_ebx.erobj'),
  (1396, 'x86_64_shr_eax_4', 1, 1, 'c1e804', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/shr_eax_4.erobj'),
  (1397, 'x86_64_push_r11', 1, 1, '4153', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/push_r11.erobj'),
  (1398, 'x86_64_shr_eax_1', 1, 1, 'd1e8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/shr_eax_1.erobj'),
  (1399, 'x86_64_mov_eax_2', 1, 1, 'b802000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_2.erobj'),
  (1400, 'x86_64_test_r9d_r9d', 1, 1, '4585c9', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/test_r9d_r9d.erobj'),
  (1401, 'x86_64_mov_esi_128', 1, 1, 'be80000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_128.erobj'),
  (1402, 'x86_64_mov_edx_r12d', 1, 1, '4489e2', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edx_r12d.erobj'),
  (1403, 'x86_64_mov_r8d_2', 1, 1, '41b802000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r8d_2.erobj'),
  (1404, 'x86_64_mov_edx_8', 1, 1, 'ba08000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edx_8.erobj');

insert or ignore into encoding_pattern(encoding_id, name, isa_id, encoding_kind, fixed_hex, immediate_type_id, immediate_operand_index, flags, object_path) values
  (1405, 'x86_64_mov_rdi_0x1234', 1, 1, '48c7c734120000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdi_0x1234.erobj'),
  (1406, 'x86_64_mov_r9d_2', 1, 1, '41b902000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r9d_2.erobj'),
  (1407, 'x86_64_mov_esi_2500', 1, 1, 'bec4090000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_2500.erobj'),
  (1408, 'x86_64_mov_rdi_1', 1, 1, '48c7c701000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdi_1.erobj'),
  (1409, 'x86_64_mov_rdx_37', 1, 1, '48c7c225000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdx_37.erobj'),
  (1410, 'x86_64_mov_rax_1', 1, 1, '48c7c001000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rax_1.erobj'),
  (1411, 'x86_64_mov_eax_0x0100000a', 1, 1, 'b80a000001', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_0x0100000a.erobj'),
  (1412, 'x86_64_mov_eax_12', 1, 1, 'b80c000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_12.erobj'),
  (1413, 'x86_64_mov_rdx_ptr_0x01020304', 1, 1, 'c70204030201', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdx_ptr_0x01020304.erobj'),
  (1414, 'x86_64_mov_eax_4', 1, 1, 'b804000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_4.erobj'),
  (1415, 'x86_64_mov_dx_0xf4', 1, 1, '66baf400', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_dx_0xf4.erobj'),
  (1416, 'x86_64_mov_eax_unexpected_http_stub_exit', 1, 1, 'b856000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_unexpected_http_stub_exit.erobj'),
  (1417, 'x86_64_out_dx_eax', 1, 1, 'ef', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/out_dx_eax.erobj'),
  (1418, 'x86_64_cli', 1, 1, 'fa', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cli.erobj'),
  (1419, 'x86_64_hlt', 1, 1, 'f4', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/hlt.erobj'),
  (1420, 'x86_64_mov_edi_unexpected_http_stub_exit', 1, 1, 'bf56000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edi_unexpected_http_stub_exit.erobj'),
  (1421, 'x86_64_mov_eax_sys_exit', 1, 1, 'b83c000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_sys_exit.erobj');

insert or ignore into encoding_pattern(encoding_id, name, isa_id, encoding_kind, fixed_hex, immediate_type_id, immediate_operand_index, flags, object_path) values
  (1422, 'x86_64_lea_rdi_r12_rbx', 1, 1, '498d3c1c', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/lea_rdi_r12_rbx.erobj'),
  (1423, 'x86_64_mov_rdi_r13_plus_8_ptr', 1, 1, '498b7d08', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdi_r13_plus_8_ptr.erobj'),
  (1424, 'x86_64_mov_al_0x0f', 1, 1, 'b00f', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_al_0x0f.erobj'),
  (1425, 'x86_64_mov_al_0x48', 1, 1, 'b048', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_al_0x48.erobj'),
  (1426, 'x86_64_cmp_edx_error_invalid_param', 1, 1, '83fa18', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_edx_error_invalid_param.erobj'),
  (1427, 'x86_64_mov_ecx_rsp_plus_40_ptr', 1, 1, '8b4c2428', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ecx_rsp_plus_40_ptr.erobj'),
  (1428, 'x86_64_test_rcx_rcx', 1, 1, '4885c9', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/test_rcx_rcx.erobj'),
  (1429, 'x86_64_mov_rsp_plus_8_ptr_rax', 1, 1, '4889442408', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsp_plus_8_ptr_rax.erobj'),
  (1430, 'x86_64_mov_edi_10', 1, 1, 'bf0a000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edi_10.erobj'),
  (1431, 'x86_64_or_rax_rdx', 1, 1, '4809d0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/or_rax_rdx.erobj'),
  (1432, 'x86_64_cmp_eax_minus_1', 1, 1, '83f8ff', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_eax_minus_1.erobj'),
  (1433, 'x86_64_test_esi_esi', 1, 1, '85f6', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/test_esi_esi.erobj'),
  (1434, 'x86_64_sub_esi_ebx', 1, 1, '29de', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/sub_esi_ebx.erobj'),
  (1435, 'x86_64_mov_edx_error_parse', 1, 1, 'ba07000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edx_error_parse.erobj'),
  (1436, 'x86_64_mov_rsp_ptr_rax', 1, 1, '48890424', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsp_ptr_rax.erobj'),
  (1437, 'x86_64_and_edi_0xff', 1, 1, '81e7ff000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/and_edi_0xff.erobj'),
  (1438, 'x86_64_push_2', 1, 1, '6a02', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/push_2.erobj'),
  (1439, 'x86_64_cmp_ecx_r12d', 1, 1, '4439e1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_ecx_r12d.erobj'),
  (1440, 'x86_64_mov_dx_di', 1, 1, '6689fa', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_dx_di.erobj'),
  (1441, 'x86_64_cmp_rax_42', 1, 1, '4883f82a', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_rax_42.erobj'),
  (1442, 'x86_64_mov_cl_2', 1, 1, 'b102', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_cl_2.erobj'),
  (1443, 'x86_64_mov_rdi_r13_rbx8_ptr', 1, 1, '498b7cdd00', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdi_r13_rbx8_ptr.erobj'),
  (1444, 'x86_64_shl_rdx_32', 1, 1, '48c1e220', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/shl_rdx_32.erobj'),
  (1445, 'x86_64_test_r8_r8', 1, 1, '4d85c0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/test_r8_r8.erobj'),
  (1446, 'x86_64_mov_sil_space', 1, 1, '40b620', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_sil_space.erobj'),
  (1447, 'x86_64_mov_al_0xc0', 1, 1, 'b0c0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_al_0xc0.erobj'),
  (1448, 'x86_64_mov_eax_0', 1, 1, 'b800000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_0.erobj'),
  (1449, 'x86_64_mov_r8d_32', 1, 1, '41b820000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r8d_32.erobj'),
  (1450, 'x86_64_mov_esi_256', 1, 1, 'be00010000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_256.erobj'),
  (1451, 'x86_64_mov_eax_sys_exit_group', 1, 1, 'b8e7000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_sys_exit_group.erobj'),
  (1452, 'x86_64_add_r8_decoded_op_size', 1, 1, '4983c020', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_r8_decoded_op_size.erobj'),
  (1453, 'arm32_cmp_r0_r1', 4, 2, '010050e1', null, -1, 0, 'kernel/x86_64/object/encoding/arm32/cmp_r0_r1.erobj'),
  (1454, 'arm32_cmp_r0_1', 4, 2, '010050e3', null, -1, 0, 'kernel/x86_64/object/encoding/arm32/cmp_r0_1.erobj'),
  (1455, 'arm32_cmp_r0_r2', 4, 2, '020050e1', null, -1, 0, 'kernel/x86_64/object/encoding/arm32/cmp_r0_r2.erobj'),
  (1456, 'arm32_cmp_r0_r3', 4, 2, '030050e1', null, -1, 0, 'kernel/x86_64/object/encoding/arm32/cmp_r0_r3.erobj'),
  (1457, 'arm32_pop_r4_r5_pc', 4, 2, '3080bde8', null, -1, 0, 'kernel/x86_64/object/encoding/arm32/pop_r4_r5_pc.erobj'),
  (1458, 'arm32_push_r4', 4, 2, '04402de5', null, -1, 0, 'kernel/x86_64/object/encoding/arm32/push_r4.erobj'),
  (1459, 'arm32_mov_r4_r0', 4, 2, '0040a0e1', null, -1, 0, 'kernel/x86_64/object/encoding/arm32/mov_r4_r0.erobj'),
  (1460, 'arm32_mov_r1_r0', 4, 2, '0010a0e1', null, -1, 0, 'kernel/x86_64/object/encoding/arm32/mov_r1_r0.erobj'),
  (1461, 'arm32_mul_r0_r2_r3', 4, 2, '920300e0', null, -1, 0, 'kernel/x86_64/object/encoding/arm32/mul_r0_r2_r3.erobj');

insert or ignore into encoding_pattern(encoding_id, name, isa_id, encoding_kind, fixed_hex, immediate_type_id, immediate_operand_index, flags, object_path) values
  (1462, 'x86_64_clc', 1, 1, 'f8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/clc.erobj'),
  (1463, 'x86_64_stc', 1, 1, 'f9', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/stc.erobj'),
  (1464, 'x86_64_cdq', 1, 1, '99', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cdq.erobj'),
  (1465, 'x86_64_rep_movsq', 1, 1, 'f348a5', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/rep_movsq.erobj'),
  (1466, 'x86_64_rep_stosd', 1, 1, 'f3ab', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/rep_stosd.erobj'),
  (1467, 'x86_64_setnz_al', 1, 1, '0f95d0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/setnz_al.erobj'),
  (1468, 'x86_64_setnp_cl', 1, 1, '0f9bd1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/setnp_cl.erobj'),
  (1469, 'x86_64_ucomiss_xmm0_xmm1', 1, 1, '0f2ec1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/ucomiss_xmm0_xmm1.erobj'),
  (1470, 'x86_64_ucomiss_xmm0_xmm0', 1, 1, '0f2ec0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/ucomiss_xmm0_xmm0.erobj'),
  (1471, 'x86_64_ucomisd_xmm0_xmm1', 1, 1, '660f2ec1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/ucomisd_xmm0_xmm1.erobj'),
  (1472, 'x86_64_ucomisd_xmm0_xmm0', 1, 1, '660f2ec0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/ucomisd_xmm0_xmm0.erobj'),
  (1473, 'x86_64_movq_xmm0_rax', 1, 1, '660f6ec0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/movq_xmm0_rax.erobj'),
  (1474, 'x86_64_movq_rax_xmm0', 1, 1, '660f7ec0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/movq_rax_xmm0.erobj'),
  (1475, 'x86_64_movq_xmm1_rax', 1, 1, '660f6ec8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/movq_xmm1_rax.erobj'),
  (1476, 'x86_64_xorps_xmm1_xmm1', 1, 1, '0f57c9', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/xorps_xmm1_xmm1.erobj'),
  (1477, 'x86_64_cvttss2si_eax_xmm0', 1, 1, 'f30f2cc0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cvttss2si_eax_xmm0.erobj'),
  (1478, 'x86_64_cvttss2si_rax_xmm0', 1, 1, 'f3480f2cc0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cvttss2si_rax_xmm0.erobj'),
  (1479, 'x86_64_cvttsd2si_eax_xmm0', 1, 1, 'f20f2cc0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cvttsd2si_eax_xmm0.erobj'),
  (1480, 'x86_64_cvttsd2si_rax_xmm0', 1, 1, 'f2480f2cc0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cvttsd2si_rax_xmm0.erobj'),
  (1481, 'x86_64_cvtsi2ss_xmm0_eax', 1, 1, 'f30f2ac0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cvtsi2ss_xmm0_eax.erobj'),
  (1482, 'x86_64_minss_xmm0_xmm1', 1, 1, 'f30f5dc1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/minss_xmm0_xmm1.erobj'),
  (1483, 'x86_64_maxss_xmm0_xmm1', 1, 1, 'f30f5fc1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/maxss_xmm0_xmm1.erobj'),
  (1484, 'x86_64_movss_xmm0_rsp_ptr', 1, 1, 'f30f100424', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/movss_xmm0_rsp_ptr.erobj');

insert or ignore into encoding_pattern(encoding_id, name, isa_id, encoding_kind, fixed_hex, immediate_type_id, immediate_operand_index, flags, object_path) values
  (1485, 'x86_64_rep_movsd', 1, 1, 'f3a5', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/rep_movsd.erobj'),
  (1486, 'x86_64_repne_scasb', 1, 1, 'f2ae', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/repne_scasb.erobj'),
  (1487, 'x86_64_setz_al', 1, 1, '0f94d0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/setz_al.erobj'),
  (1488, 'x86_64_rdtscp', 1, 1, '0f01f9', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/rdtscp.erobj'),
  (1489, 'x86_64_rol_ax_8', 1, 1, '66c1c008', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/rol_ax_8.erobj'),
  (1490, 'x86_64_cmovl_eax_edx', 1, 1, '0f4cc2', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmovl_eax_edx.erobj');

insert or ignore into encoding_pattern(encoding_id, name, isa_id, encoding_kind, fixed_hex, immediate_type_id, immediate_operand_index, flags, object_path) values
  (1491, 'x86_64_lodsb', 1, 1, 'ac', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/lodsb.erobj'),
  (1492, 'x86_64_cqo', 1, 1, '4899', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cqo.erobj'),
  (1493, 'x86_64_rol_cx_8', 1, 1, '66c1c108', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/rol_cx_8.erobj'),
  (1494, 'x86_64_lfence', 1, 1, '0faee8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/lfence.erobj'),
  (1495, 'x86_64_rdmsr', 1, 1, '0f32', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/rdmsr.erobj'),
  (1496, 'x86_64_wrmsr', 1, 1, '0f30', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/wrmsr.erobj'),
  (1497, 'x86_64_rol_eax_cl', 1, 1, 'd3c0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/rol_eax_cl.erobj'),
  (1498, 'x86_64_rol_rax_cl', 1, 1, '48d3c0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/rol_rax_cl.erobj'),
  (1499, 'x86_64_ror_eax_cl', 1, 1, 'd3c8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/ror_eax_cl.erobj'),
  (1500, 'x86_64_adc_ax_0', 1, 1, '6683d000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/adc_ax_0.erobj'),
  (1501, 'x86_64_cvtsi2sd_xmm0_eax', 1, 1, 'f20f2ac0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cvtsi2sd_xmm0_eax.erobj'),
  (1502, 'x86_64_cvtsi2sd_xmm0_rax', 1, 1, 'f2480f2ac0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cvtsi2sd_xmm0_rax.erobj'),
  (1503, 'x86_64_cvtsi2ss_xmm0_rax', 1, 1, 'f3480f2ac0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cvtsi2ss_xmm0_rax.erobj'),
  (1504, 'x86_64_cvtss2si_eax_xmm0', 1, 1, 'f30f2dc0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cvtss2si_eax_xmm0.erobj'),
  (1505, 'x86_64_pxor_xmm4_xmm4', 1, 1, '660fefe4', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/pxor_xmm4_xmm4.erobj'),
  (1506, 'x86_64_sqrtss_xmm0_xmm0', 1, 1, 'f30f51c0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/sqrtss_xmm0_xmm0.erobj'),
  (1507, 'x86_64_xorps_xmm0_xmm0', 1, 1, '0f57c0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/xorps_xmm0_xmm0.erobj'),
  (1508, 'x86_64_mov_esi_local_max_identities', 1, 1, 'be10000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_local_max_identities.erobj'),
  (1509, 'x86_64_mov_edx_seal_encoded_size', 1, 1, 'ba74000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edx_seal_encoded_size.erobj'),
  (1510, 'x86_64_mov_edx_msg_test_len', 1, 1, 'ba04000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edx_msg_test_len.erobj'),
  (1511, 'x86_64_mov_ecx_msg_blind_len', 1, 1, 'b90d000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ecx_msg_blind_len.erobj'),
  (1512, 'x86_64_mov_edx_raw_size', 1, 1, 'ba6a000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edx_raw_size.erobj'),
  (1513, 'x86_64_mov_esi_stamp_size', 1, 1, 'be40000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_stamp_size.erobj'),
  (1514, 'x86_64_mov_esi_domain_len', 1, 1, 'be13000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_domain_len.erobj'),
  (1515, 'x86_64_mov_ecx_value_len', 1, 1, 'b908000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ecx_value_len.erobj'),
  (1516, 'x86_64_imul_eax_eax_31', 1, 1, '6bc01f', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/imul_eax_eax_31.erobj'),
  (1517, 'x86_64_add_eax_7', 1, 1, '83c007', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_eax_7.erobj'),
  (1518, 'x86_64_cmp_ecx_data_size', 1, 1, '81f9dc050000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_ecx_data_size.erobj'),
  (1519, 'x86_64_mov_esi_data_size', 1, 1, 'bedc050000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_data_size.erobj'),
  (1520, 'x86_64_mov_rsi_rbx_host_import_name_ptr', 1, 1, '488b7310', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsi_rbx_host_import_name_ptr.erobj'),
  (1521, 'x86_64_add_rbx_host_import_size', 1, 1, '4883c328', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_rbx_host_import_size.erobj'),
  (1522, 'x86_64_mov_dl_agent_flag_sync', 1, 1, 'b201', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_dl_agent_flag_sync.erobj'),
  (1523, 'x86_64_imul_rax_host_import_size', 1, 1, '486bc028', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/imul_rax_host_import_size.erobj'),
  (1524, 'x86_64_mov_r15_rax_host_import_fn_ptr', 1, 1, '4c8b7820', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r15_rax_host_import_fn_ptr.erobj'),
  (1525, 'x86_64_mov_rdi_rax_host_import_module_ptr', 1, 1, '488b38', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdi_rax_host_import_module_ptr.erobj'),
  (1526, 'x86_64_mov_rdi_rax_host_import_name_ptr', 1, 1, '488b7810', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdi_rax_host_import_name_ptr.erobj'),
  (1527, 'x86_64_mov_rsi_rax_host_import_module_len', 1, 1, '488b7008', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsi_rax_host_import_module_len.erobj'),
  (1528, 'x86_64_mov_rsi_rax_host_import_name_len', 1, 1, '488b7018', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsi_rax_host_import_name_len.erobj'),
  (1529, 'x86_64_test_bl_agent_flag_sync', 1, 1, 'f6c301', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/test_bl_agent_flag_sync.erobj'),
  (1530, 'x86_64_test_cl_agent_flag_sync', 1, 1, 'f6c101', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/test_cl_agent_flag_sync.erobj'),
  (1531, 'x86_64_mov_rsi_bytes_pattern64', 1, 1, '48be8877665544332211', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsi_bytes_pattern64.erobj'),
  (1532, 'x86_64_mov_rbx_bytes_pattern64', 1, 1, '48bb8877665544332211', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rbx_bytes_pattern64.erobj'),
  (1533, 'x86_64_cmp_rax_rbx', 1, 1, '4839d8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_rax_rbx.erobj'),
  (1534, 'x86_64_mov_esi_bytes_pattern32', 1, 1, 'be44332211', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_bytes_pattern32.erobj'),
  (1535, 'x86_64_mov_esi_aabb', 1, 1, 'bebbaa0000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_aabb.erobj'),
  (1536, 'x86_64_mov_r15d_r9d', 1, 1, '4589cf', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r15d_r9d.erobj'),
  (1537, 'x86_64_mov_rsp16_rax', 1, 1, '4889442410', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsp16_rax.erobj'),
  (1538, 'x86_64_cmp_r10d_eax', 1, 1, '4139c2', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_r10d_eax.erobj'),
  (1539, 'x86_64_add_eax_4', 1, 1, '83c004', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_eax_4.erobj'),
  (1540, 'x86_64_mov_rcx_rsp', 1, 1, '4889e1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rcx_rsp.erobj'),
  (1541, 'x86_64_add_rsp_40', 1, 1, '4883c428', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_rsp_40.erobj'),
  (1542, 'x86_64_mov_esi_rsp_ptr', 1, 1, '8b3424', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_rsp_ptr.erobj'),
  (1543, 'x86_64_imul_eax_r14d', 1, 1, '410fafc6', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/imul_eax_r14d.erobj'),
  (1544, 'x86_64_imul_eax_ecx', 1, 1, '0fafc1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/imul_eax_ecx.erobj'),
  (1545, 'x86_64_add_rsp_56', 1, 1, '4883c438', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_rsp_56.erobj'),
  (1546, 'x86_64_mov_r8d_r15d', 1, 1, '4589f8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r8d_r15d.erobj'),
  (1547, 'x86_64_mov_rsp_ptr_ecx', 1, 1, '890c24', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsp_ptr_ecx.erobj'),
  (1548, 'x86_64_mov_ecx_r11d', 1, 1, '4489d9', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ecx_r11d.erobj'),
  (1549, 'x86_64_mov_ecx_r12d', 1, 1, '4489e1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ecx_r12d.erobj'),
  (1550, 'x86_64_mov_esi_rsp8_ptr', 1, 1, '8b742408', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_rsp8_ptr.erobj'),
  (1551, 'x86_64_cmp_eax_255', 1, 1, '3dff000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_eax_255.erobj'),
  (1552, 'x86_64_cmp_ecx_4', 1, 1, '83f904', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_ecx_4.erobj'),
  (1553, 'x86_64_shl_eax_4', 1, 1, 'c1e004', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/shl_eax_4.erobj'),
  (1554, 'x86_64_shr_ecx_1', 1, 1, 'd1e9', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/shr_ecx_1.erobj'),
  (1555, 'x86_64_mov_ecx_r13d', 1, 1, '4489e9', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ecx_r13d.erobj'),
  (1556, 'x86_64_mov_rsp32_rax', 1, 1, '4889442420', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsp32_rax.erobj'),
  (1557, 'x86_64_mov_rsp40_rax', 1, 1, '4889442428', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsp40_rax.erobj'),
  (1558, 'x86_64_cmp_ebx_eax', 1, 1, '39c3', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_ebx_eax.erobj'),
  (1559, 'x86_64_mov_r8d_ebx', 1, 1, '4189d8', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r8d_ebx.erobj'),
  (1560, 'x86_64_shl_ecx_6', 1, 1, 'c1e106', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/shl_ecx_6.erobj'),
  (1561, 'x86_64_add_eax_esi', 1, 1, '01f0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_eax_esi.erobj'),
  (1562, 'x86_64_cmp_ecx_ebx', 1, 1, '39d9', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_ecx_ebx.erobj'),
  (1563, 'x86_64_cmp_eax_5', 1, 1, '83f805', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_eax_5.erobj'),
  (1564, 'x86_64_mov_rdi_rcx_ptr_al', 1, 1, '88040f', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdi_rcx_ptr_al.erobj'),
  (1565, 'x86_64_cmp_ecx_eax', 1, 1, '39c1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_ecx_eax.erobj'),
  (1566, 'x86_64_shl_edx_16', 1, 1, 'c1e210', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/shl_edx_16.erobj'),
  (1567, 'x86_64_mov_esi_ecx', 1, 1, '89ce', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_esi_ecx.erobj'),
  (1568, 'x86_64_mov_rdi_rsp_ptr', 1, 1, '488b3c24', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdi_rsp_ptr.erobj'),
  (1569, 'x86_64_mov_r8_r14', 1, 1, '4d89f0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r8_r14.erobj'),
  (1570, 'x86_64_mov_r8d_r10d', 1, 1, '4589d0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r8d_r10d.erobj'),
  (1571, 'x86_64_mov_rsi_rcx', 1, 1, '4889ce', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsi_rcx.erobj'),
  (1572, 'x86_64_cmp_ecx_r14d', 1, 1, '4439f1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_ecx_r14d.erobj'),
  (1573, 'x86_64_mov_eax_rsp4_ptr', 1, 1, '8b442404', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_rsp4_ptr.erobj'),
  (1574, 'x86_64_mov_rsi_rsp_ptr', 1, 1, '488b3424', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsi_rsp_ptr.erobj'),
  (1575, 'x86_64_mov_eax_rsp24_ptr', 1, 1, '8b442418', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_rsp24_ptr.erobj'),
  (1576, 'x86_64_mov_rcx_rsp16_ptr', 1, 1, '488b4c2410', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rcx_rsp16_ptr.erobj'),
  (1577, 'x86_64_mov_r9_rbx', 1, 1, '4989d9', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r9_rbx.erobj'),
  (1578, 'x86_64_cmp_r9d_r14d', 1, 1, '4539f1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_r9d_r14d.erobj'),
  (1579, 'x86_64_shl_ecx_8', 1, 1, 'c1e108', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/shl_ecx_8.erobj'),
  (1580, 'x86_64_mov_dword_rsp_ptr_0', 1, 1, 'c7042400000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_dword_rsp_ptr_0.erobj'),
  (1581, 'x86_64_mov_ebx_2', 1, 1, 'bb02000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ebx_2.erobj'),
  (1582, 'x86_64_mov_eax_3', 1, 1, 'b803000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_3.erobj'),
  (1583, 'x86_64_add_ecx_edx', 1, 1, '01d1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_ecx_edx.erobj'),
  (1584, 'x86_64_mov_rdi_rsp8_ptr', 1, 1, '488b7c2408', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdi_rsp8_ptr.erobj'),
  (1585, 'x86_64_mov_edx_rsp4_ptr', 1, 1, '8b542404', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_edx_rsp4_ptr.erobj'),
  (1586, 'x86_64_mov_rsp8_eax', 1, 1, '89442408', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsp8_eax.erobj'),
  (1587, 'x86_64_mov_rsp_rcx_dl', 1, 1, '88140c', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsp_rcx_dl.erobj'),
  (1588, 'x86_64_shl_edx_8', 1, 1, 'c1e208', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/shl_edx_8.erobj'),
  (1589, 'x86_64_mov_ecx_r9d', 1, 1, '4489c9', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ecx_r9d.erobj'),
  (1590, 'x86_64_mov_ecx_edx', 1, 1, '89d1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_ecx_edx.erobj'),
  (1591, 'x86_64_cmp_esi_3', 1, 1, '83fe03', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cmp_esi_3.erobj'),
  (1592, 'x86_64_imul_eax_r8d', 1, 1, '410fafc0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/imul_eax_r8d.erobj'),
  (1593, 'x86_64_mov_rsp_ptr_r9', 1, 1, '4c890c24', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rsp_ptr_r9.erobj'),
  (1594, 'x86_64_test_edi_edi', 1, 1, '85ff', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/test_edi_edi.erobj'),
  (1595, 'x86_64_add_ecx_eax', 1, 1, '01c1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_ecx_eax.erobj'),
  (1596, 'x86_64_imul_eax_r13d', 1, 1, '410fafc5', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/imul_eax_r13d.erobj'),
  (1597, 'x86_64_mov_dword_rsp4_ptr_0', 1, 1, 'c744240400000000', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_dword_rsp4_ptr_0.erobj'),
  (1598, 'x86_64_mov_r13_r8', 1, 1, '4d89c5', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r13_r8.erobj'),
  (1599, 'x86_64_mov_rdi1_ptr_al', 1, 1, '884701', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rdi1_ptr_al.erobj'),
  (1600, 'x86_64_add_r11d_eax', 1, 1, '4101c3', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/add_r11d_eax.erobj'),
  (1601, 'x86_64_mov_r10_rsp8_ptr', 1, 1, '4c8b542408', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_r10_rsp8_ptr.erobj'),
  (1602, 'x86_64_lea_rdx_rsp_ptr', 1, 1, '488d1424', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/lea_rdx_rsp_ptr.erobj'),
  (1603, 'x86_64_lea_rdi_r13_rax_ptr', 1, 1, '498d7c0500', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/lea_rdi_r13_rax_ptr.erobj');

create table function_object (
  function_id integer primary key,
  name text not null unique,
  isa_id integer not null references isa(isa_id),
  entry_record_id integer not null,
  object_path text not null unique
);

create table function_record (
  function_id integer not null references function_object(function_id),
  record_id integer not null,
  sequence integer not null,
  record_kind integer not null,
  form_path text not null,
  encoding_id integer not null references encoding_pattern(encoding_id),
  primary key (function_id, record_id),
  unique (function_id, sequence)
);

create table function_operand (
  function_id integer not null,
  record_id integer not null,
  operand_index integer not null,
  operand_id integer not null references concrete_operand(operand_id),
  primary key (function_id, record_id, operand_index),
  foreign key (function_id, record_id) references function_record(function_id, record_id)
);

create table function_edge (
  function_id integer not null,
  from_record_id integer not null,
  edge_kind integer not null,
  to_record_id integer not null,
  primary key (function_id, from_record_id, edge_kind),
  foreign key (function_id, from_record_id) references function_record(function_id, record_id),
  foreign key (function_id, to_record_id) references function_record(function_id, record_id)
);

insert into function_object(function_id, name, isa_id, entry_record_id, object_path) values
  (1, 'return_42_x86_64', 1, 1, 'kernel/x86_64/object/function/return_42_x86_64.erobj');

insert into function_record(function_id, record_id, sequence, record_kind, form_path, encoding_id) values
  (1, 1, 1, 1, 'kernel/x86_64/object/form/x86_64/mov_eax_imm32.erobj', 1), (1, 2, 2, 1, 'kernel/x86_64/object/form/x86_64/ret.erobj', 2);

insert into function_operand(function_id, record_id, operand_index, operand_id) values
  (1, 1, 0, 100), (1, 1, 1, 102), (1, 2, 0, 1);

insert into function_edge(function_id, from_record_id, edge_kind, to_record_id) values
  (1, 1, 1, 2);

create view function_flat_byte_chunks as
select
  function_object.name as function_name,
  function_record.sequence,
  case
    when encoding_pattern.name = 'x86_64_mov_eax_imm32' then encoding_pattern.fixed_hex || '2a000000'
    else encoding_pattern.fixed_hex
  end as hex_chunk
from function_record
join function_object using (function_id)
join encoding_pattern using (encoding_id)
order by function_record.sequence;

create view function_flat_hex as
select function_name, group_concat(hex_chunk, '') as hex_bytes
from function_flat_byte_chunks
group by function_name;

-- Canonical program graph editing model.
--
-- These tables are the SQL editing surface for code. They are not a generic
-- text-file import. Text source may attach as provenance later, but edits that
-- matter should operate on modules, functions, blocks, instruction instances,
-- operands, symbols, relocations, and control edges.

create table program_module (
  module_id integer primary key,
  name text not null unique,
  isa_id integer not null references isa(isa_id),
  root_function_id integer references function_object(function_id),
  object_path text not null unique
);

create table function_basic_block (
  function_id integer not null references function_object(function_id),
  block_id integer not null,
  name text not null,
  sequence integer not null,
  entry_record_id integer not null,
  flags integer not null default 0,
  primary key (function_id, block_id),
  unique (function_id, name),
  unique (function_id, sequence)
);

create table instruction_instance (
  function_id integer not null,
  record_id integer not null,
  block_id integer not null,
  sequence integer not null,
  form_path text not null,
  instruction_path text not null,
  encoding_id integer not null references encoding_pattern(encoding_id),
  flags integer not null default 0,
  primary key (function_id, record_id),
  foreign key (function_id, block_id) references function_basic_block(function_id, block_id),
  unique (function_id, block_id, sequence)
);

create table instruction_operand_binding (
  function_id integer not null,
  record_id integer not null,
  operand_index integer not null,
  operand_id integer not null references concrete_operand(operand_id),
  role integer not null default 0,
  primary key (function_id, record_id, operand_index),
  foreign key (function_id, record_id) references instruction_instance(function_id, record_id)
);

create table control_edge (
  function_id integer not null,
  from_record_id integer not null,
  edge_kind integer not null,
  to_record_id integer not null,
  flags integer not null default 0,
  primary key (function_id, from_record_id, edge_kind),
  foreign key (function_id, from_record_id) references instruction_instance(function_id, record_id),
  foreign key (function_id, to_record_id) references instruction_instance(function_id, record_id)
);

create table symbol_object (
  symbol_id integer primary key,
  module_id integer not null references program_module(module_id),
  name text not null,
  symbol_kind integer not null,
  function_id integer references function_object(function_id),
  record_id integer,
  flags integer not null default 0,
  unique (module_id, name)
);

create table relocation_object (
  relocation_id integer primary key,
  function_id integer not null,
  record_id integer not null,
  operand_index integer not null,
  relocation_kind integer not null,
  target_symbol_id integer references symbol_object(symbol_id),
  addend integer not null default 0,
  foreign key (function_id, record_id, operand_index)
    references instruction_operand_binding(function_id, record_id, operand_index)
);

insert into program_module(module_id, name, isa_id, root_function_id, object_path) values
  (1, 'bootstrap_x86_64_functions', 1, 1, 'kernel/x86_64/object/module/bootstrap_x86_64_functions.erobj');

insert into function_basic_block(function_id, block_id, name, sequence, entry_record_id, flags) values
  (1, 1, 'entry', 1, 1, 1);

insert into instruction_instance(function_id, record_id, block_id, sequence, form_path, instruction_path, encoding_id, flags) values
  (1, 1, 1, 1,
   'kernel/x86_64/object/form/x86_64/mov_eax_imm32.erobj',
   'kernel/x86_64/object/instruction/x86_64/mov_eax_imm32.erobj',
   1, 0),
  (1, 2, 1, 2,
   'kernel/x86_64/object/form/x86_64/ret.erobj',
   'kernel/x86_64/object/instruction/x86_64/ret.erobj',
   2, 0);

insert into instruction_operand_binding(function_id, record_id, operand_index, operand_id, role) values
  (1, 1, 0, 100, 1),
  (1, 1, 1, 102, 2),
  (1, 2, 0, 1, 0);

insert into control_edge(function_id, from_record_id, edge_kind, to_record_id, flags) values
  (1, 1, 1, 2, 0);

insert into symbol_object(symbol_id, module_id, name, symbol_kind, function_id, record_id, flags) values
  (1, 1, 'return_42_x86_64', 1, 1, 1, 1);

create view canonical_function_closure as
select function_object.name as function_name,
       'function' as object_role,
       function_object.object_path as object_path
from function_object
union all
select function_object.name, 'form', instruction_instance.form_path
from instruction_instance join function_object using (function_id)
union all
select function_object.name, 'instruction', instruction_instance.instruction_path
from instruction_instance join function_object using (function_id)
union all
select function_object.name, 'encoding', encoding_pattern.object_path
from instruction_instance
join function_object using (function_id)
join encoding_pattern using (encoding_id)
union all
select function_object.name, 'operand', concrete_operand.object_path
from instruction_operand_binding
join function_object using (function_id)
join concrete_operand using (operand_id);

create view canonical_instruction_byte_chunks as
select function_object.name as function_name,
       instruction_instance.block_id,
       instruction_instance.sequence,
       case
         when encoding_pattern.name = 'x86_64_mov_eax_imm32' then
           encoding_pattern.fixed_hex || printf('%02x%02x%02x%02x',
             concrete_operand.immediate_value & 255,
             (concrete_operand.immediate_value >> 8) & 255,
             (concrete_operand.immediate_value >> 16) & 255,
             (concrete_operand.immediate_value >> 24) & 255)
         else encoding_pattern.fixed_hex
       end as hex_chunk
from instruction_instance
join function_object using (function_id)
join encoding_pattern using (encoding_id)
left join instruction_operand_binding
  on instruction_operand_binding.function_id = instruction_instance.function_id
 and instruction_operand_binding.record_id = instruction_instance.record_id
 and instruction_operand_binding.operand_index = encoding_pattern.immediate_operand_index
left join concrete_operand using (operand_id)
order by instruction_instance.block_id, instruction_instance.sequence;

create view canonical_function_flat_hex as
select function_name, group_concat(hex_chunk, '') as hex_bytes
from canonical_instruction_byte_chunks
group by function_name;

-- Pure language import and abstraction model.
--
-- Languages are import rule sets over syntax and semantics. Source text is not
-- stored as authority here; it can be provenance outside this graph. Importing
-- code means extracting modules, functions, values, operations, bindings,
-- control flow, data flow, and effects into canonical abstraction rows. If a
-- construct has no rule, it cannot exist in the imported graph.

create table language (
  language_id integer primary key,
  name text not null unique,
  family text not null,
  version text not null,
  object_path text not null unique
);

insert into language(language_id, name, family, version, object_path) values
  (1, 'asm_x86_intel', 'assembly', 'canonical-seed', 'kernel/x86_64/object/language/asm_x86_intel.erobj'),
  (2, 'wasm_binary', 'wasm', '1.0', 'kernel/x86_64/object/language/wasm_binary.erobj'),
  (3, 'wasm_text', 'wasm', '1.0', 'kernel/x86_64/object/language/wasm_text.erobj'),
  (4, 'c', 'systems', 'c17-subset', 'kernel/x86_64/object/language/c.erobj'),
  (5, 'zig', 'systems', 'bootstrap-subset', 'kernel/x86_64/object/language/zig.erobj'),
  (6, 'sql', 'relational', 'sqlite-subset', 'kernel/x86_64/object/language/sql.erobj');

create table syntax_atom (
  syntax_atom_id integer primary key,
  language_id integer not null references language(language_id),
  name text not null,
  syntax_class integer not null,
  arity integer not null,
  flags integer not null default 0,
  object_path text not null unique,
  unique (language_id, name)
);

insert into syntax_atom(syntax_atom_id, language_id, name, syntax_class, arity, flags, object_path) values
  (1, 1, 'instruction', 1, -1, 0, 'kernel/x86_64/object/syntax/asm_x86_intel/instruction.erobj'),
  (2, 1, 'label', 2, 1, 0, 'kernel/x86_64/object/syntax/asm_x86_intel/label.erobj'),
  (3, 1, 'directive', 3, -1, 0, 'kernel/x86_64/object/syntax/asm_x86_intel/directive.erobj'),
  (10, 2, 'section', 1, -1, 0, 'kernel/x86_64/object/syntax/wasm_binary/section.erobj'),
  (11, 2, 'function_body', 2, -1, 0, 'kernel/x86_64/object/syntax/wasm_binary/function_body.erobj'),
  (12, 2, 'opcode', 3, -1, 0, 'kernel/x86_64/object/syntax/wasm_binary/opcode.erobj'),
  (20, 4, 'translation_unit', 1, -1, 0, 'kernel/x86_64/object/syntax/c/translation_unit.erobj'),
  (21, 4, 'function_definition', 2, -1, 0, 'kernel/x86_64/object/syntax/c/function_definition.erobj'),
  (22, 4, 'compound_statement', 3, -1, 0, 'kernel/x86_64/object/syntax/c/compound_statement.erobj'),
  (23, 4, 'return_statement', 4, 1, 0, 'kernel/x86_64/object/syntax/c/return_statement.erobj'),
  (24, 4, 'integer_constant', 5, 0, 0, 'kernel/x86_64/object/syntax/c/integer_constant.erobj'),
  (30, 5, 'source_file', 1, -1, 0, 'kernel/x86_64/object/syntax/zig/source_file.erobj'),
  (31, 5, 'fn_decl', 2, -1, 0, 'kernel/x86_64/object/syntax/zig/fn_decl.erobj'),
  (32, 5, 'block', 3, -1, 0, 'kernel/x86_64/object/syntax/zig/block.erobj'),
  (33, 5, 'return_expr', 4, 1, 0, 'kernel/x86_64/object/syntax/zig/return_expr.erobj'),
  (34, 5, 'integer_literal', 5, 0, 0, 'kernel/x86_64/object/syntax/zig/integer_literal.erobj'),
  (40, 6, 'select', 1, -1, 0, 'kernel/x86_64/object/syntax/sql/select.erobj'),
  (41, 6, 'insert', 2, -1, 0, 'kernel/x86_64/object/syntax/sql/insert.erobj'),
  (42, 6, 'create_table', 3, -1, 0, 'kernel/x86_64/object/syntax/sql/create_table.erobj');

create table abstraction_kind (
  abstraction_kind_id integer primary key,
  name text not null unique,
  flags integer not null default 0,
  object_path text not null unique
);

insert into abstraction_kind(abstraction_kind_id, name, flags, object_path) values
  (1, 'module', 1, 'kernel/x86_64/object/abstraction_kind/module.erobj'),
  (2, 'function', 1, 'kernel/x86_64/object/abstraction_kind/function.erobj'),
  (3, 'block', 1, 'kernel/x86_64/object/abstraction_kind/block.erobj'),
  (4, 'operation', 0, 'kernel/x86_64/object/abstraction_kind/operation.erobj'),
  (5, 'value', 0, 'kernel/x86_64/object/abstraction_kind/value.erobj'),
  (6, 'binding', 0, 'kernel/x86_64/object/abstraction_kind/binding.erobj'),
  (7, 'type', 0, 'kernel/x86_64/object/abstraction_kind/type.erobj'),
  (8, 'control', 0, 'kernel/x86_64/object/abstraction_kind/control.erobj'),
  (9, 'data', 0, 'kernel/x86_64/object/abstraction_kind/data.erobj'),
  (10, 'effect', 0, 'kernel/x86_64/object/abstraction_kind/effect.erobj'),
  (11, 'import', 0, 'kernel/x86_64/object/abstraction_kind/import.erobj'),
  (12, 'export', 0, 'kernel/x86_64/object/abstraction_kind/export.erobj'),
  (13, 'pipeline_stage', 0, 'kernel/x86_64/object/abstraction_kind/pipeline_stage.erobj');

create table semantic_rule (
  semantic_rule_id integer primary key,
  language_id integer not null references language(language_id),
  syntax_atom_id integer not null references syntax_atom(syntax_atom_id),
  abstraction_kind_id integer not null references abstraction_kind(abstraction_kind_id),
  rule_name text not null,
  output_role integer not null,
  flags integer not null default 0,
  object_path text not null unique,
  unique (language_id, syntax_atom_id, rule_name)
);

insert into semantic_rule(semantic_rule_id, language_id, syntax_atom_id, abstraction_kind_id, rule_name, output_role, flags, object_path) values
  (1, 1, 1, 4, 'instruction_to_operation', 1, 0, 'kernel/x86_64/object/rule/asm_x86_intel/instruction_to_operation.erobj'),
  (2, 1, 2, 8, 'label_to_control_anchor', 1, 0, 'kernel/x86_64/object/rule/asm_x86_intel/label_to_control_anchor.erobj'),
  (10, 2, 11, 2, 'wasm_function_body_to_function', 1, 0, 'kernel/x86_64/object/rule/wasm_binary/function_body_to_function.erobj'),
  (11, 2, 12, 4, 'wasm_opcode_to_operation', 1, 0, 'kernel/x86_64/object/rule/wasm_binary/opcode_to_operation.erobj'),
  (20, 4, 21, 2, 'c_function_definition_to_function', 1, 0, 'kernel/x86_64/object/rule/c/function_definition_to_function.erobj'),
  (21, 4, 23, 8, 'c_return_statement_to_control', 1, 0, 'kernel/x86_64/object/rule/c/return_statement_to_control.erobj'),
  (22, 4, 24, 5, 'c_integer_constant_to_value', 1, 0, 'kernel/x86_64/object/rule/c/integer_constant_to_value.erobj'),
  (30, 5, 31, 2, 'zig_fn_decl_to_function', 1, 0, 'kernel/x86_64/object/rule/zig/fn_decl_to_function.erobj'),
  (31, 5, 33, 8, 'zig_return_expr_to_control', 1, 0, 'kernel/x86_64/object/rule/zig/return_expr_to_control.erobj'),
  (32, 5, 34, 5, 'zig_integer_literal_to_value', 1, 0, 'kernel/x86_64/object/rule/zig/integer_literal_to_value.erobj'),
  (40, 6, 40, 13, 'sql_select_to_pipeline_stage', 1, 0, 'kernel/x86_64/object/rule/sql/select_to_pipeline_stage.erobj');

create table import_unit (
  import_unit_id integer primary key,
  language_id integer not null references language(language_id),
  name text not null unique,
  source_object_path text,
  root_abstraction_id integer,
  flags integer not null default 0
);

create table abstraction_node (
  abstraction_id integer primary key,
  import_unit_id integer references import_unit(import_unit_id),
  abstraction_kind_id integer not null references abstraction_kind(abstraction_kind_id),
  name text not null,
  type_id integer references value_type(type_id),
  function_id integer references function_object(function_id),
  module_id integer references program_module(module_id),
  literal_integer integer,
  flags integer not null default 0,
  object_path text not null unique
);

create table abstraction_edge (
  edge_id integer primary key,
  from_abstraction_id integer not null references abstraction_node(abstraction_id),
  to_abstraction_id integer not null references abstraction_node(abstraction_id),
  edge_kind integer not null,
  ordinal integer not null default 0,
  flags integer not null default 0
);

create table pipeline_node (
  pipeline_node_id integer primary key,
  abstraction_id integer not null references abstraction_node(abstraction_id),
  sequence integer not null,
  stage_kind integer not null,
  flags integer not null default 0,
  unique (abstraction_id, sequence)
);

create table pipeline_edge (
  pipeline_edge_id integer primary key,
  from_pipeline_node_id integer not null references pipeline_node(pipeline_node_id),
  to_pipeline_node_id integer not null references pipeline_node(pipeline_node_id),
  edge_kind integer not null,
  flags integer not null default 0
);

create table lowering_rule (
  lowering_rule_id integer primary key,
  abstraction_kind_id integer not null references abstraction_kind(abstraction_kind_id),
  target_isa_id integer not null references isa(isa_id),
  target_form_path text,
  target_encoding_id integer references encoding_pattern(encoding_id),
  rule_name text not null,
  flags integer not null default 0,
  unique (abstraction_kind_id, target_isa_id, rule_name)
);

insert into lowering_rule(lowering_rule_id, abstraction_kind_id, target_isa_id, target_form_path, target_encoding_id, rule_name, flags) values
  (1, 5, 1, 'kernel/x86_64/object/form/x86_64/mov_eax_imm32.erobj', 1, 'u32_return_value_to_eax', 0),
  (2, 8, 1, 'kernel/x86_64/object/form/x86_64/ret.erobj', 2, 'return_control_to_ret', 0);

insert into import_unit(import_unit_id, language_id, name, source_object_path, root_abstraction_id, flags) values
  (1, 4, 'return_42_imported_abstraction', null, 1, 1);

insert into abstraction_node(abstraction_id, import_unit_id, abstraction_kind_id, name, type_id, function_id, module_id, literal_integer, flags, object_path) values
  (1, 1, 1, 'bootstrap_x86_64_functions', null, null, 1, null, 1, 'kernel/x86_64/object/abstraction/bootstrap_x86_64_functions.erobj'),
  (2, 1, 2, 'return_42_x86_64', null, 1, 1, null, 1, 'kernel/x86_64/object/abstraction/return_42_x86_64.function.erobj'),
  (3, 1, 3, 'entry', null, 1, 1, null, 0, 'kernel/x86_64/object/abstraction/return_42_x86_64.entry_block.erobj'),
  (4, 1, 5, 'constant_42', 5, 1, 1, 42, 0, 'kernel/x86_64/object/abstraction/return_42_x86_64.constant_42.erobj'),
  (5, 1, 8, 'return', null, 1, 1, null, 0, 'kernel/x86_64/object/abstraction/return_42_x86_64.return.erobj');

insert into abstraction_edge(edge_id, from_abstraction_id, to_abstraction_id, edge_kind, ordinal, flags) values
  (1, 1, 2, 1, 0, 0),
  (2, 2, 3, 1, 0, 0),
  (3, 3, 4, 2, 0, 0),
  (4, 4, 5, 3, 0, 0);

insert into pipeline_node(pipeline_node_id, abstraction_id, sequence, stage_kind, flags) values
  (1, 4, 1, 1, 0),
  (2, 5, 2, 2, 0);

insert into pipeline_edge(pipeline_edge_id, from_pipeline_node_id, to_pipeline_node_id, edge_kind, flags) values
  (1, 1, 2, 1, 0);

create view importable_language_rules as
select language.name as language_name,
       syntax_atom.name as syntax_atom,
       semantic_rule.rule_name,
       abstraction_kind.name as abstraction_kind
from semantic_rule
join language using (language_id)
join syntax_atom using (syntax_atom_id)
join abstraction_kind using (abstraction_kind_id)
order by language.name, syntax_atom.name, semantic_rule.rule_name;

create view abstraction_function_projection as
select abstraction_node.name as abstraction_name,
       function_object.name as function_name,
       canonical_function_flat_hex.hex_bytes
from abstraction_node
join function_object using (function_id)
join canonical_function_flat_hex on canonical_function_flat_hex.function_name = function_object.name
where abstraction_node.abstraction_kind_id = 2;

-- Relational rule engine proof model.
--
-- The same abstract operation graph can be interpreted, lowered, and assembled
-- by different queries. These tables are deliberately rule-shaped: operations
-- have signatures, values have types, data edges connect operations, type rules
-- define valid signatures, effect rules define behavior classes, and lowering
-- rules map abstract operations to target instruction/form/encoding rows.

create table operation_kind (
  operation_kind_id integer primary key,
  name text not null unique,
  result_type_id integer references value_type(type_id),
  input_count integer not null,
  flags integer not null default 0,
  object_path text not null unique
);

insert into operation_kind(operation_kind_id, name, result_type_id, input_count, flags, object_path) values
  (1, 'const_i32', 22, 0, 1, 'kernel/x86_64/object/operation_kind/const_i32.erobj'),
  (2, 'return_value', 1, 1, 2, 'kernel/x86_64/object/operation_kind/return_value.erobj'),
  (3, 'add_i32', 22, 2, 0, 'kernel/x86_64/object/operation_kind/add_i32.erobj'),
  (4, 'sub_i32', 22, 2, 0, 'kernel/x86_64/object/operation_kind/sub_i32.erobj'),
  (5, 'load_i32', 22, 1, 4, 'kernel/x86_64/object/operation_kind/load_i32.erobj'),
  (6, 'store_i32', 1, 2, 8, 'kernel/x86_64/object/operation_kind/store_i32.erobj'),
  (7, 'call', null, -1, 16, 'kernel/x86_64/object/operation_kind/call.erobj'),
  (8, 'branch', 1, 1, 32, 'kernel/x86_64/object/operation_kind/branch.erobj');

create table operation_signature (
  operation_kind_id integer not null references operation_kind(operation_kind_id),
  operand_index integer not null,
  type_id integer not null references value_type(type_id),
  role integer not null default 0,
  primary key (operation_kind_id, operand_index)
);

insert into operation_signature(operation_kind_id, operand_index, type_id, role) values
  (2, 0, 22, 1),
  (3, 0, 22, 1),
  (3, 1, 22, 1),
  (4, 0, 22, 1),
  (4, 1, 22, 1),
  (5, 0, 62, 1),
  (6, 0, 62, 1),
  (6, 1, 22, 2),
  (8, 0, 123, 1);

create table type_rule (
  type_rule_id integer primary key,
  operation_kind_id integer not null references operation_kind(operation_kind_id),
  input_type0 integer references value_type(type_id),
  input_type1 integer references value_type(type_id),
  result_type_id integer references value_type(type_id),
  rule_name text not null unique
);

insert into type_rule(type_rule_id, operation_kind_id, input_type0, input_type1, result_type_id, rule_name) values
  (1, 1, null, null, 22, 'const_i32_yields_i32'),
  (2, 2, 22, null, 1, 'return_i32_is_valid'),
  (3, 3, 22, 22, 22, 'add_i32_i32_to_i32'),
  (4, 4, 22, 22, 22, 'sub_i32_i32_to_i32'),
  (5, 5, 62, null, 22, 'load_ptr64_to_i32'),
  (6, 6, 62, 22, 1, 'store_ptr64_i32');

create table effect_kind (
  effect_kind_id integer primary key,
  name text not null unique,
  flags integer not null default 0
);

insert into effect_kind(effect_kind_id, name, flags) values
  (1, 'pure_value', 1),
  (2, 'control_return', 2),
  (3, 'memory_read', 4),
  (4, 'memory_write', 8),
  (5, 'call', 16),
  (6, 'branch', 32);

create table effect_rule (
  effect_rule_id integer primary key,
  operation_kind_id integer not null references operation_kind(operation_kind_id),
  effect_kind_id integer not null references effect_kind(effect_kind_id),
  rule_name text not null unique
);

insert into effect_rule(effect_rule_id, operation_kind_id, effect_kind_id, rule_name) values
  (1, 1, 1, 'const_i32_is_pure'),
  (2, 2, 2, 'return_value_returns_control'),
  (3, 3, 1, 'add_i32_is_pure'),
  (4, 4, 1, 'sub_i32_is_pure'),
  (5, 5, 3, 'load_i32_reads_memory'),
  (6, 6, 4, 'store_i32_writes_memory'),
  (7, 7, 5, 'call_has_call_effect'),
  (8, 8, 6, 'branch_has_control_effect');

create table value_instance (
  value_id integer primary key,
  function_id integer not null references function_object(function_id),
  name text not null,
  type_id integer not null references value_type(type_id),
  literal_integer integer,
  producer_operation_id integer,
  flags integer not null default 0,
  unique (function_id, name)
);

create table operation_instance (
  operation_id integer primary key,
  function_id integer not null references function_object(function_id),
  block_id integer not null,
  sequence integer not null,
  operation_kind_id integer not null references operation_kind(operation_kind_id),
  result_value_id integer references value_instance(value_id),
  literal_integer integer,
  flags integer not null default 0,
  unique (function_id, block_id, sequence)
);

create table operation_input (
  operation_id integer not null references operation_instance(operation_id),
  operand_index integer not null,
  value_id integer not null references value_instance(value_id),
  primary key (operation_id, operand_index)
);

create table data_edge (
  data_edge_id integer primary key,
  from_value_id integer not null references value_instance(value_id),
  to_operation_id integer not null references operation_instance(operation_id),
  operand_index integer not null,
  unique (to_operation_id, operand_index)
);

insert into value_instance(value_id, function_id, name, type_id, literal_integer, producer_operation_id, flags) values
  (1, 1, 'const_42_value', 22, 42, 1, 1),
  (2, 1, 'return_result', 1, null, 2, 2);

insert into operation_instance(operation_id, function_id, block_id, sequence, operation_kind_id, result_value_id, literal_integer, flags) values
  (1, 1, 1, 1, 1, 1, 42, 0),
  (2, 1, 1, 2, 2, 2, null, 0);

insert into operation_input(operation_id, operand_index, value_id) values
  (2, 0, 1);

insert into data_edge(data_edge_id, from_value_id, to_operation_id, operand_index) values
  (1, 1, 2, 0);

create table abstract_lowering_rule (
  abstract_lowering_rule_id integer primary key,
  operation_kind_id integer not null references operation_kind(operation_kind_id),
  target_isa_id integer not null references isa(isa_id),
  target_form_path text not null,
  target_instruction_path text not null,
  target_encoding_id integer not null references encoding_pattern(encoding_id),
  output_order integer not null,
  rule_name text not null,
  unique (operation_kind_id, target_isa_id, rule_name)
);

insert into abstract_lowering_rule(abstract_lowering_rule_id, operation_kind_id, target_isa_id, target_form_path, target_instruction_path, target_encoding_id, output_order, rule_name) values
  (1, 1, 1,
   'kernel/x86_64/object/form/x86_64/mov_eax_imm32.erobj',
   'kernel/x86_64/object/instruction/x86_64/mov_eax_imm32.erobj',
   1, 1, 'const_i32_to_x86_64_mov_eax_imm32'),
  (2, 2, 1,
   'kernel/x86_64/object/form/x86_64/ret.erobj',
   'kernel/x86_64/object/instruction/x86_64/ret.erobj',
   2, 1, 'return_value_to_x86_64_ret');

create view valid_operation_types as
select operation_instance.operation_id,
       function_object.name as function_name,
       operation_kind.name as operation_name,
       type_rule.rule_name
from operation_instance
join function_object using (function_id)
join operation_kind using (operation_kind_id)
left join operation_input input0 on input0.operation_id = operation_instance.operation_id and input0.operand_index = 0
left join value_instance value0 on value0.value_id = input0.value_id
left join operation_input input1 on input1.operation_id = operation_instance.operation_id and input1.operand_index = 1
left join value_instance value1 on value1.value_id = input1.value_id
join type_rule on type_rule.operation_kind_id = operation_instance.operation_kind_id
 and coalesce(type_rule.input_type0, coalesce(value0.type_id, -1)) = coalesce(value0.type_id, coalesce(type_rule.input_type0, -1))
 and coalesce(type_rule.input_type1, coalesce(value1.type_id, -1)) = coalesce(value1.type_id, coalesce(type_rule.input_type1, -1));

create view interpreted_steps as
select operation_instance.function_id,
       function_object.name as function_name,
       operation_instance.sequence,
       operation_kind.name as operation_name,
       case operation_kind.name
         when 'const_i32' then operation_instance.literal_integer
         when 'return_value' then input_value.literal_integer
       end as value_integer,
       effect_kind.name as effect_name
from operation_instance
join function_object using (function_id)
join operation_kind using (operation_kind_id)
join effect_rule using (operation_kind_id)
join effect_kind using (effect_kind_id)
left join operation_input on operation_input.operation_id = operation_instance.operation_id and operation_input.operand_index = 0
left join value_instance input_value on input_value.value_id = operation_input.value_id
order by operation_instance.sequence;

create view interpreted_function_result as
select function_name, value_integer as return_value
from interpreted_steps
where operation_name = 'return_value';

create view lowered_instruction_stream as
select function_object.name as function_name,
       isa.name as target_isa,
       operation_instance.sequence,
       operation_kind.name as source_operation,
       abstract_lowering_rule.target_instruction_path as instruction_path,
       abstract_lowering_rule.target_form_path as form_path,
       abstract_lowering_rule.target_encoding_id as encoding_id,
       case operation_kind.name
         when 'const_i32' then operation_instance.literal_integer
         else null
       end as immediate_value
from operation_instance
join function_object using (function_id)
join operation_kind using (operation_kind_id)
join abstract_lowering_rule using (operation_kind_id)
join isa on isa.isa_id = abstract_lowering_rule.target_isa_id
where abstract_lowering_rule.target_isa_id = function_object.isa_id
order by operation_instance.sequence, abstract_lowering_rule.output_order;

create view rule_engine_byte_chunks as
select lowered_instruction_stream.function_name,
       lowered_instruction_stream.target_isa,
       lowered_instruction_stream.sequence,
       case
         when encoding_pattern.name = 'x86_64_mov_eax_imm32' then
           encoding_pattern.fixed_hex || printf('%02x%02x%02x%02x',
             lowered_instruction_stream.immediate_value & 255,
             (lowered_instruction_stream.immediate_value >> 8) & 255,
             (lowered_instruction_stream.immediate_value >> 16) & 255,
             (lowered_instruction_stream.immediate_value >> 24) & 255)
         else encoding_pattern.fixed_hex
       end as hex_chunk
from lowered_instruction_stream
join encoding_pattern using (encoding_id)
order by lowered_instruction_stream.sequence;

create view rule_engine_flat_hex as
select function_name, target_isa, group_concat(hex_chunk, '') as hex_bytes
from rule_engine_byte_chunks
group by function_name, target_isa;

create view materialized_object_roots as
select 'isa' as layer, name as namespace, object_path from isa
union all
select 'register_set', isa.name, register_set.object_path
from register_set join isa using (isa_id);

-- EdgeRun ASM DSL import workbench.
--
-- This is the first codebase-specific importer surface. The agent operates this
-- by querying gaps, adding rules/objects, and rerunning import/materialization
-- until real repository functions lower and assemble from canonical relations.

insert into language(language_id, name, family, version, object_path) values
  (7, 'edgerun_asm_dsl', 'assembly-dsl', 'bootstrap', 'kernel/x86_64/object/language/edgerun_asm_dsl.erobj');

insert into syntax_atom(syntax_atom_id, language_id, name, syntax_class, arity, flags, object_path) values
  (100, 7, 'function_decl', 1, 1, 0, 'kernel/x86_64/object/syntax/edgerun_asm_dsl/function_decl.erobj'),
  (101, 7, 'label_decl', 2, 1, 0, 'kernel/x86_64/object/syntax/edgerun_asm_dsl/label_decl.erobj'),
  (102, 7, 'macro_call', 3, -1, 0, 'kernel/x86_64/object/syntax/edgerun_asm_dsl/macro_call.erobj'),
  (103, 7, 'instruction', 4, -1, 0, 'kernel/x86_64/object/syntax/edgerun_asm_dsl/instruction.erobj'),
  (104, 7, 'directive', 5, -1, 0, 'kernel/x86_64/object/syntax/edgerun_asm_dsl/directive.erobj'),
  (105, 7, 'equ_constant', 6, 2, 0, 'kernel/x86_64/object/syntax/edgerun_asm_dsl/equ_constant.erobj'),
  (106, 7, 'include', 7, 1, 0, 'kernel/x86_64/object/syntax/edgerun_asm_dsl/include.erobj'),
  (107, 7, 'data_decl', 8, -1, 0, 'kernel/x86_64/object/syntax/edgerun_asm_dsl/data_decl.erobj'),
  (108, 7, 'comment', 9, 0, 0, 'kernel/x86_64/object/syntax/edgerun_asm_dsl/comment.erobj');

insert into semantic_rule(semantic_rule_id, language_id, syntax_atom_id, abstraction_kind_id, rule_name, output_role, flags, object_path) values
  (100, 7, 100, 2, 'er_fn_to_function', 1, 0, 'kernel/x86_64/object/rule/edgerun_asm_dsl/er_fn_to_function.erobj'),
  (101, 7, 101, 8, 'label_to_control_anchor', 1, 0, 'kernel/x86_64/object/rule/edgerun_asm_dsl/label_to_control_anchor.erobj'),
  (102, 7, 102, 4, 'known_macro_to_operation', 1, 0, 'kernel/x86_64/object/rule/edgerun_asm_dsl/known_macro_to_operation.erobj'),
  (103, 7, 103, 4, 'known_instruction_to_operation', 1, 0, 'kernel/x86_64/object/rule/edgerun_asm_dsl/known_instruction_to_operation.erobj'),
  (104, 7, 104, 11, 'include_to_import', 1, 0, 'kernel/x86_64/object/rule/edgerun_asm_dsl/include_to_import.erobj');

create table asm_dsl_source (
  asm_source_id integer primary key,
  source_object_path text not null unique,
  module_name text not null,
  language_id integer not null references language(language_id)
);

create table asm_dsl_line (
  asm_source_id integer not null references asm_dsl_source(asm_source_id),
  line_id integer not null,
  line_kind integer not null,
  label_name text,
  op_name text,
  operand_text text,
  raw_text text not null,
  primary key (asm_source_id, line_id)
);

create table asm_dsl_function_span (
  asm_source_id integer not null references asm_dsl_source(asm_source_id),
  asm_function_id integer not null,
  function_name text not null,
  start_line_id integer not null,
  end_line_id integer not null,
  target_isa_id integer not null references isa(isa_id),
  primary key (asm_source_id, asm_function_id),
  unique (asm_source_id, function_name)
);

create table asm_dsl_rule (
  asm_rule_id integer primary key,
  line_kind integer not null,
  op_name text not null,
  operation_kind_id integer references operation_kind(operation_kind_id),
  instruction_path text,
  form_path text,
  encoding_id integer references encoding_pattern(encoding_id),
  rule_name text not null unique,
  exact_operand_text text,
  flags integer not null default 0
);

insert into asm_dsl_rule(asm_rule_id, line_kind, op_name, operation_kind_id, instruction_path, form_path, encoding_id, rule_name, exact_operand_text, flags) values
  (1, 1, 'er_fn', null, null, null, null, 'er_fn_declares_function', null, 1),
  (2, 3, 'ret', 2, 'kernel/x86_64/object/instruction/x86_64/ret.erobj', 'kernel/x86_64/object/form/x86_64/ret.erobj', 2, 'ret_to_return_value', '', 0),
  (3, 3, 'nop', null, 'kernel/x86_64/object/instruction/x86_64/nop.erobj', 'kernel/x86_64/object/form/x86_64/nop.erobj', 3, 'nop_to_nop', '', 0),
  (4, 3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', 'kernel/x86_64/object/form/x86_64/mov.erobj', null, 'mov_general_requires_operand_rule', null, 2),
  (5, 3, 'xor', null, 'kernel/x86_64/object/instruction/x86_64/xor.erobj', 'kernel/x86_64/object/form/x86_64/xor.erobj', null, 'xor_general_requires_operand_rule', null, 2),
  (6, 3, 'call', 7, 'kernel/x86_64/object/instruction/x86_64/call.erobj', 'kernel/x86_64/object/form/x86_64/call.erobj', null, 'call_requires_symbol_resolution', null, 2),
  (7, 3, 'jmp', 8, 'kernel/x86_64/object/instruction/x86_64/jmp.erobj', 'kernel/x86_64/object/form/x86_64/jmp.erobj', null, 'jmp_requires_label_resolution', null, 2),
  (8, 4, '%include', null, null, null, null, 'include_to_import_edge', '', 1),
  (9, 5, 'equ', null, null, null, null, 'equ_to_constant_binding', '', 1),
  (10, 2, '', null, null, null, null, 'asm_label', null, 1),
  (11, 3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', 'kernel/x86_64/object/form/x86_64/mov.erobj', 82, 'asm_x86_mov_rcx_rsi_exact', 'rcx, rsi', 0),
  (12, 3, 'sub', null, 'kernel/x86_64/object/instruction/x86_64/sub.erobj', null, 83, 'asm_x86_sub_rcx_rdi', 'rcx, rdi', 0),
  (13, 3, 'jle', null, 'kernel/x86_64/object/instruction/x86_64/jle.erobj', null, 84, 'asm_x86_jle_rel8_10', '.done', 0),
  (14, 3, 'xor', null, 'kernel/x86_64/object/instruction/x86_64/xor.erobj', 'kernel/x86_64/object/form/x86_64/xor.erobj', 85, 'asm_x86_xor_eax_eax_exact', 'eax, eax', 0),
  (15, 3, 'cld', null, 'kernel/x86_64/object/instruction/x86_64/cld.erobj', null, 86, 'asm_x86_cld', '', 0),
  (16, 3, 'shr', null, 'kernel/x86_64/object/instruction/x86_64/shr.erobj', null, 87, 'asm_x86_shr_rcx_3', 'rcx, 3', 0),
  (17, 3, 'rep', null, 'kernel/x86_64/object/instruction/x86_64/rep.erobj', null, 88, 'asm_x86_rep_stosq', 'stosq', 0),
  (18, 3, 'er_check_zero', null, null, null, null, 'asm_dsl_macro_er_check_zero', null, 2),
  (19, 3, 'er_ret', null, null, null, null, 'asm_dsl_macro_er_ret', null, 2),
  (20, 3, 'er_err', null, null, null, null, 'asm_dsl_macro_er_err', null, 2),
  (21, 3, 'er_ok', null, null, null, null, 'asm_dsl_macro_er_ok', null, 2),
  (22, 3, 'er_check_nonzero', null, null, null, null, 'asm_dsl_macro_er_check_nonzero', null, 2),
  (23, 3, 'er_pop', null, null, null, null, 'asm_dsl_macro_er_pop', null, 2),
  (24, 3, 'er_push', null, null, null, null, 'asm_dsl_macro_er_push', null, 2),
  (25, 4, 'global', null, null, null, null, 'global_to_export_symbol', null, 1);

insert or ignore into asm_dsl_rule(line_kind, op_name, operation_kind_id, instruction_path, form_path, encoding_id, rule_name, exact_operand_text, flags)
select 3,
       instruction.mnemonic,
       null,
       instruction.object_path,
       null,
       null,
       'asm_x86_' || instruction.mnemonic || '_generic',
       null,
       2
from instruction
join isa using (isa_id)
where isa.name = 'x86_64'
  and instruction.mnemonic in (
    'cmp','lea','add','test','movzx','pop','inc','je','jne','push','jae','sub','jle',
    'cld','shr','or','and','dec','jb','jg','jl','jge','jbe','ja','sete','setne',
    'cmove','cmovne','imul','mul','div','idiv','shl','sar','not','neg','xchg',
    'cmpxchg','bswap','bsf','bsr','bt','bts','btr','btc','hlt','cli','sti','rdtsc','cpuid'
  );

insert or ignore into asm_dsl_rule(line_kind, op_name, operation_kind_id, instruction_path, form_path, encoding_id, rule_name, exact_operand_text, flags)
select 3, 'jz', null, instruction.object_path, null, null, 'asm_x86_jz_alias_generic', null, 2
from instruction join isa using (isa_id)
where isa.name = 'x86_64' and instruction.mnemonic = 'je';

insert or ignore into asm_dsl_rule(line_kind, op_name, operation_kind_id, instruction_path, form_path, encoding_id, rule_name, exact_operand_text, flags)
select 3, 'jnz', null, instruction.object_path, null, null, 'asm_x86_jnz_alias_generic', null, 2
from instruction join isa using (isa_id)
where isa.name = 'x86_64' and instruction.mnemonic = 'jne';

insert or ignore into asm_dsl_rule(line_kind, op_name, operation_kind_id, instruction_path, form_path, encoding_id, rule_name, exact_operand_text, flags)
select 3,
       instruction.mnemonic,
       null,
       instruction.object_path,
       null,
       null,
       'asm_x86_' || instruction.mnemonic || '_known_gap',
       null,
       2
from instruction
join isa using (isa_id)
where isa.name = 'x86_64'
  and instruction.mnemonic in ('syscall','js','jc','movsx','out','in');

insert or ignore into asm_dsl_rule(line_kind, op_name, operation_kind_id, instruction_path, form_path, encoding_id, rule_name, exact_operand_text, flags) values
  (3, 'ASSERT_EQ', null, null, null, null, 'test_macro_assert_eq', null, 2),
  (3, 'ASSERT_RDX', null, null, null, null, 'test_macro_assert_rdx', null, 2),
  (3, 'ASSERT_RAX', null, null, null, null, 'test_macro_assert_rax', null, 2),
  (3, 'ASSERT_MEM_EQ', null, null, null, null, 'test_macro_assert_mem_eq', null, 2),
  (3, 'ASSERT_DWORD', null, null, null, null, 'test_macro_assert_dword', null, 2),
  (3, 'ASSERT_BYTE', null, null, null, null, 'test_macro_assert_byte', null, 2),
  (3, 'ASSERT_QWORD', null, null, null, null, 'test_macro_assert_qword', null, 2),
  (3, 'TEST_CALL_EAX', null, null, null, null, 'test_macro_call_eax', null, 2),
  (3, 'er_stack_alloc', null, null, null, null, 'asm_dsl_macro_er_stack_alloc', null, 2),
  (3, 'er_stack_free', null, null, null, null, 'asm_dsl_macro_er_stack_free', null, 2),
  (3, 'er_pop_ret', null, null, null, null, 'asm_dsl_macro_er_pop_ret', null, 2),
  (3, 'er_call', null, null, null, null, 'asm_dsl_macro_er_call', null, 2),
  (3, 'er_frame_pop', null, null, null, null, 'asm_dsl_macro_er_frame_pop', null, 2),
  (3, 'er_frame_push_regs', null, null, null, null, 'asm_dsl_macro_er_frame_push_regs', null, 2),
  (3, 'db', null, null, null, null, 'data_decl_db', null, 1),
  (3, 'dw', null, null, null, null, 'data_decl_dw', null, 1),
  (3, 'dd', null, null, null, null, 'data_decl_dd', null, 1),
  (3, 'SECTION', null, null, null, null, 'section_directive_upper', null, 1),
  (4, '%macro', null, null, null, null, 'macro_definition_start', null, 1),
  (4, '%endm', null, null, null, null, 'macro_definition_end', null, 1),
  (4, '%endif', null, null, null, null, 'conditional_definition_end', null, 1);

insert or ignore into asm_dsl_rule(line_kind, op_name, operation_kind_id, instruction_path, form_path, encoding_id, rule_name, exact_operand_text, flags) values
  (3, 'syscall', null, 'kernel/x86_64/object/instruction/x86_64/syscall.erobj', null, 1000, 'asm_x86_syscall_exact', '', 0),
  (3, 'test', null, 'kernel/x86_64/object/instruction/x86_64/test.erobj', null, 1001, 'asm_x86_test_eax_eax_exact', 'eax, eax', 0),
  (3, 'test', null, 'kernel/x86_64/object/instruction/x86_64/test.erobj', null, 1002, 'asm_x86_test_edx_edx_exact', 'edx, edx', 0),
  (3, 'test', null, 'kernel/x86_64/object/instruction/x86_64/test.erobj', null, 1003, 'asm_x86_test_rdx_rdx_exact', 'rdx, rdx', 0),
  (3, 'test', null, 'kernel/x86_64/object/instruction/x86_64/test.erobj', null, 1004, 'asm_x86_test_rdi_rdi_exact', 'rdi, rdi', 0),
  (3, 'test', null, 'kernel/x86_64/object/instruction/x86_64/test.erobj', null, 1005, 'asm_x86_test_rax_rax_exact', 'rax, rax', 0),
  (3, 'test', null, 'kernel/x86_64/object/instruction/x86_64/test.erobj', null, 1006, 'asm_x86_test_rsi_rsi_exact', 'rsi, rsi', 0),
  (3, 'xor', null, 'kernel/x86_64/object/instruction/x86_64/xor.erobj', null, 1007, 'asm_x86_xor_edx_edx_exact', 'edx, edx', 0),
  (3, 'xor', null, 'kernel/x86_64/object/instruction/x86_64/xor.erobj', null, 1008, 'asm_x86_xor_ecx_ecx_exact', 'ecx, ecx', 0),
  (3, 'xor', null, 'kernel/x86_64/object/instruction/x86_64/xor.erobj', null, 1009, 'asm_x86_xor_esi_esi_exact', 'esi, esi', 0),
  (3, 'xor', null, 'kernel/x86_64/object/instruction/x86_64/xor.erobj', null, 1010, 'asm_x86_xor_ebx_ebx_exact', 'ebx, ebx', 0),
  (3, 'xor', null, 'kernel/x86_64/object/instruction/x86_64/xor.erobj', null, 1011, 'asm_x86_xor_edi_edi_exact', 'edi, edi', 0),
  (3, 'xor', null, 'kernel/x86_64/object/instruction/x86_64/xor.erobj', null, 1012, 'asm_x86_xor_r8d_r8d_exact', 'r8d, r8d', 0),
  (3, 'xor', null, 'kernel/x86_64/object/instruction/x86_64/xor.erobj', null, 1013, 'asm_x86_xor_r9d_r9d_exact', 'r9d, r9d', 0),
  (3, 'push', null, 'kernel/x86_64/object/instruction/x86_64/push.erobj', null, 1014, 'asm_x86_push_rax_exact', 'rax', 0),
  (3, 'push', null, 'kernel/x86_64/object/instruction/x86_64/push.erobj', null, 1015, 'asm_x86_push_rcx_exact', 'rcx', 0),
  (3, 'push', null, 'kernel/x86_64/object/instruction/x86_64/push.erobj', null, 1016, 'asm_x86_push_rbx_exact', 'rbx', 0),
  (3, 'push', null, 'kernel/x86_64/object/instruction/x86_64/push.erobj', null, 1017, 'asm_x86_push_rbp_exact', 'rbp', 0),
  (3, 'push', null, 'kernel/x86_64/object/instruction/x86_64/push.erobj', null, 1018, 'asm_x86_push_r12_exact', 'r12', 0),
  (3, 'push', null, 'kernel/x86_64/object/instruction/x86_64/push.erobj', null, 1019, 'asm_x86_push_r13_exact', 'r13', 0),
  (3, 'push', null, 'kernel/x86_64/object/instruction/x86_64/push.erobj', null, 1020, 'asm_x86_push_r14_exact', 'r14', 0),
  (3, 'push', null, 'kernel/x86_64/object/instruction/x86_64/push.erobj', null, 1021, 'asm_x86_push_r15_exact', 'r15', 0),
  (3, 'pop', null, 'kernel/x86_64/object/instruction/x86_64/pop.erobj', null, 1022, 'asm_x86_pop_rax_exact', 'rax', 0),
  (3, 'pop', null, 'kernel/x86_64/object/instruction/x86_64/pop.erobj', null, 1023, 'asm_x86_pop_rcx_exact', 'rcx', 0),
  (3, 'pop', null, 'kernel/x86_64/object/instruction/x86_64/pop.erobj', null, 1024, 'asm_x86_pop_rbx_exact', 'rbx', 0),
  (3, 'pop', null, 'kernel/x86_64/object/instruction/x86_64/pop.erobj', null, 1025, 'asm_x86_pop_rbp_exact', 'rbp', 0),
  (3, 'pop', null, 'kernel/x86_64/object/instruction/x86_64/pop.erobj', null, 1026, 'asm_x86_pop_r12_exact', 'r12', 0),
  (3, 'pop', null, 'kernel/x86_64/object/instruction/x86_64/pop.erobj', null, 1027, 'asm_x86_pop_r13_exact', 'r13', 0),
  (3, 'pop', null, 'kernel/x86_64/object/instruction/x86_64/pop.erobj', null, 1028, 'asm_x86_pop_r14_exact', 'r14', 0),
  (3, 'pop', null, 'kernel/x86_64/object/instruction/x86_64/pop.erobj', null, 1029, 'asm_x86_pop_r15_exact', 'r15', 0);

insert or ignore into asm_dsl_rule(line_kind, op_name, operation_kind_id, instruction_path, form_path, encoding_id, rule_name, exact_operand_text, flags) values
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1030, 'asm_x86_mov_rdi_r12_exact', 'rdi, r12', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1031, 'asm_x86_mov_eax_minus_one_exact', 'eax, -1', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1032, 'asm_x86_mov_r12_rdi_exact', 'r12, rdi', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1033, 'asm_x86_mov_rdi_rbx_exact', 'rdi, rbx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1034, 'asm_x86_mov_eax_1_exact', 'eax, 1', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1035, 'asm_x86_mov_rsi_r13_exact', 'rsi, r13', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1036, 'asm_x86_mov_esi_r13d_exact', 'esi, r13d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1037, 'asm_x86_mov_eax_ebx_exact', 'eax, ebx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1038, 'asm_x86_mov_rdi_rsp_exact', 'rdi, rsp', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1039, 'asm_x86_mov_rdi_r14_exact', 'rdi, r14', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1040, 'asm_x86_mov_rsi_r12_exact', 'rsi, r12', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1041, 'asm_x86_mov_rdi_r13_exact', 'rdi, r13', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1042, 'asm_x86_mov_edi_r12d_exact', 'edi, r12d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1043, 'asm_x86_mov_r13d_esi_exact', 'r13d, esi', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1044, 'asm_x86_mov_rbx_rax_exact', 'rbx, rax', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1045, 'asm_x86_mov_esi_eax_exact', 'esi, eax', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1046, 'asm_x86_mov_r13_rsi_exact', 'r13, rsi', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1047, 'asm_x86_mov_rdx_r14_exact', 'rdx, r14', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1048, 'asm_x86_mov_rbx_rdi_exact', 'rbx, rdi', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1049, 'asm_x86_mov_eax_r14d_exact', 'eax, r14d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1050, 'asm_x86_mov_rdi_r15_exact', 'rdi, r15', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1051, 'asm_x86_mov_r14_rdx_exact', 'r14, rdx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1052, 'asm_x86_mov_ecx_eax_exact', 'ecx, eax', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1053, 'asm_x86_mov_ebx_eax_exact', 'ebx, eax', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1054, 'asm_x86_mov_eax_ecx_exact', 'eax, ecx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1055, 'asm_x86_mov_rsi_r15_exact', 'rsi, r15', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1056, 'asm_x86_mov_edi_ebx_exact', 'edi, ebx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1057, 'asm_x86_mov_edx_ebx_exact', 'edx, ebx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1058, 'asm_x86_mov_eax_edi_exact', 'eax, edi', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1059, 'asm_x86_mov_r13_rdx_exact', 'r13, rdx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1060, 'asm_x86_mov_rsi_r14_exact', 'rsi, r14', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1061, 'asm_x86_mov_esi_r12d_exact', 'esi, r12d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1062, 'asm_x86_mov_eax_esi_exact', 'eax, esi', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1063, 'asm_x86_mov_eax_r13d_exact', 'eax, r13d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1064, 'asm_x86_mov_r14d_edx_exact', 'r14d, edx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1065, 'asm_x86_mov_eax_r15d_exact', 'eax, r15d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1066, 'asm_x86_mov_edi_r14d_exact', 'edi, r14d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1067, 'asm_x86_mov_edx_eax_exact', 'edx, eax', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1068, 'asm_x86_mov_rdi_rax_exact', 'rdi, rax', 0);

insert or ignore into asm_dsl_rule(line_kind, op_name, operation_kind_id, instruction_path, form_path, encoding_id, rule_name, exact_operand_text, flags) values
  (3, 'inc', null, 'kernel/x86_64/object/instruction/x86_64/inc.erobj', null, 1069, 'asm_x86_inc_ecx_exact', 'ecx', 0),
  (3, 'inc', null, 'kernel/x86_64/object/instruction/x86_64/inc.erobj', null, 1070, 'asm_x86_inc_ebx_exact', 'ebx', 0),
  (3, 'inc', null, 'kernel/x86_64/object/instruction/x86_64/inc.erobj', null, 1071, 'asm_x86_inc_rbx_exact', 'rbx', 0),
  (3, 'inc', null, 'kernel/x86_64/object/instruction/x86_64/inc.erobj', null, 1072, 'asm_x86_inc_eax_exact', 'eax', 0),
  (3, 'inc', null, 'kernel/x86_64/object/instruction/x86_64/inc.erobj', null, 1073, 'asm_x86_inc_rdi_exact', 'rdi', 0),
  (3, 'inc', null, 'kernel/x86_64/object/instruction/x86_64/inc.erobj', null, 1074, 'asm_x86_inc_rax_exact', 'rax', 0),
  (3, 'inc', null, 'kernel/x86_64/object/instruction/x86_64/inc.erobj', null, 1075, 'asm_x86_inc_r15d_exact', 'r15d', 0),
  (3, 'inc', null, 'kernel/x86_64/object/instruction/x86_64/inc.erobj', null, 1076, 'asm_x86_inc_r12_exact', 'r12', 0),
  (3, 'inc', null, 'kernel/x86_64/object/instruction/x86_64/inc.erobj', null, 1077, 'asm_x86_inc_r14d_exact', 'r14d', 0),
  (3, 'inc', null, 'kernel/x86_64/object/instruction/x86_64/inc.erobj', null, 1078, 'asm_x86_inc_r8d_exact', 'r8d', 0),
  (3, 'inc', null, 'kernel/x86_64/object/instruction/x86_64/inc.erobj', null, 1079, 'asm_x86_inc_r9d_exact', 'r9d', 0),
  (3, 'inc', null, 'kernel/x86_64/object/instruction/x86_64/inc.erobj', null, 1080, 'asm_x86_inc_r10_exact', 'r10', 0),
  (3, 'inc', null, 'kernel/x86_64/object/instruction/x86_64/inc.erobj', null, 1081, 'asm_x86_inc_rcx_exact', 'rcx', 0),
  (3, 'inc', null, 'kernel/x86_64/object/instruction/x86_64/inc.erobj', null, 1082, 'asm_x86_inc_r10d_exact', 'r10d', 0),
  (3, 'inc', null, 'kernel/x86_64/object/instruction/x86_64/inc.erobj', null, 1083, 'asm_x86_inc_r13_exact', 'r13', 0),
  (3, 'inc', null, 'kernel/x86_64/object/instruction/x86_64/inc.erobj', null, 1084, 'asm_x86_inc_r11d_exact', 'r11d', 0),
  (3, 'inc', null, 'kernel/x86_64/object/instruction/x86_64/inc.erobj', null, 1085, 'asm_x86_inc_edx_exact', 'edx', 0),
  (3, 'inc', null, 'kernel/x86_64/object/instruction/x86_64/inc.erobj', null, 1086, 'asm_x86_inc_r8_exact', 'r8', 0),
  (3, 'inc', null, 'kernel/x86_64/object/instruction/x86_64/inc.erobj', null, 1087, 'asm_x86_inc_rsi_exact', 'rsi', 0),
  (3, 'inc', null, 'kernel/x86_64/object/instruction/x86_64/inc.erobj', null, 1088, 'asm_x86_inc_ebp_exact', 'ebp', 0),
  (3, 'inc', null, 'kernel/x86_64/object/instruction/x86_64/inc.erobj', null, 1089, 'asm_x86_inc_r13d_exact', 'r13d', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1090, 'asm_x86_add_rsp_16_exact', 'rsp, 16', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1091, 'asm_x86_add_rsp_8_exact', 'rsp, 8', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1092, 'asm_x86_add_eax_ecx_exact', 'eax, ecx', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1093, 'asm_x86_add_eax_edx_exact', 'eax, edx', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1094, 'asm_x86_add_ebx_eax_exact', 'ebx, eax', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1095, 'asm_x86_add_rsp_24_exact', 'rsp, 24', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1096, 'asm_x86_add_rsp_32_exact', 'rsp, 32', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1097, 'asm_x86_add_edi_eax_exact', 'edi, eax', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1098, 'asm_x86_add_eax_ebx_exact', 'eax, ebx', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1099, 'asm_x86_add_r15d_eax_exact', 'r15d, eax', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1100, 'asm_x86_add_rax_rcx_exact', 'rax, rcx', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1101, 'asm_x86_add_eax_r8d_exact', 'eax, r8d', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1102, 'asm_x86_add_rdi_rax_exact', 'rdi, rax', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1103, 'asm_x86_add_rbx_rax_exact', 'rbx, rax', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1104, 'asm_x86_add_edx_eax_exact', 'edx, eax', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1105, 'asm_x86_add_edx_ecx_exact', 'edx, ecx', 0);

insert or ignore into asm_dsl_rule(line_kind, op_name, operation_kind_id, instruction_path, form_path, encoding_id, rule_name, exact_operand_text, flags) values
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1106, 'asm_x86_mov_rdi_com1_port_exact', 'rdi, COM1_PORT', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1107, 'asm_x86_mov_edi_com1_port_exact', 'edi, COM1_PORT', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1108, 'asm_x86_mov_r12_com1_port_exact', 'r12, COM1_PORT', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1109, 'asm_x86_mov_r14_com1_port_exact', 'r14, COM1_PORT', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1110, 'asm_x86_mov_rsi_com1_port_exact', 'rsi, COM1_PORT', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1111, 'asm_x86_mov_rax_rbx_runtime_memory_ptr_exact', 'rax, [rbx + RUNTIME_MEMORY_PTR_OFF]', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1112, 'asm_x86_cmp_rbx_runtime_ticks_ptr_zero_exact', 'qword [rbx + RUNTIME_TICKS_PTR_OFF], 0', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1113, 'asm_x86_cmp_rbx_runtime_memory_len_da_app_memory_exact', 'qword [rbx + RUNTIME_MEMORY_LEN_OFF], DA_APP_MEMORY_BYTES', 0);

insert or ignore into asm_dsl_rule(line_kind, op_name, operation_kind_id, instruction_path, form_path, encoding_id, rule_name, exact_operand_text, flags) values
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1114, 'asm_x86_mov_rdx_rs4_exact', 'rdx, RS*4', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1115, 'asm_x86_mov_ecx_vs4_exact', 'ecx, VS*4', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1116, 'asm_x86_mov_rdx_48_exact', 'rdx, 48', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1117, 'asm_x86_mov_ecx_rs4_exact', 'ecx, RS*4', 0),
  (3, 'movd', null, 'kernel/x86_64/object/instruction/x86_64/movd.erobj', null, 1118, 'asm_x86_movd_xmm2_eax_exact', 'xmm2, eax', 0),
  (3, 'movd', null, 'kernel/x86_64/object/instruction/x86_64/movd.erobj', null, 1119, 'asm_x86_movd_xmm3_eax_exact', 'xmm3, eax', 0),
  (3, 'pxor', null, 'kernel/x86_64/object/instruction/x86_64/pxor.erobj', null, 1120, 'asm_x86_pxor_xmm0_xmm0_exact', 'xmm0, xmm0', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1121, 'asm_x86_mov_eax_0x3f800000_exact', 'eax, 0x3F800000', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1122, 'asm_x86_mov_r9d_minus_one_exact', 'r9d, 0xFFFFFFFF', 0),
  (3, 'pxor', null, 'kernel/x86_64/object/instruction/x86_64/pxor.erobj', null, 1123, 'asm_x86_pxor_xmm1_xmm1_exact', 'xmm1, xmm1', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1124, 'asm_x86_mov_ecx_da_export_name_len_exact', 'ecx, DA_EXPORT_NAME_LEN', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1125, 'asm_x86_mov_ecx_is4_exact', 'ecx, IS*4', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1126, 'asm_x86_mov_edx_minus_one_exact', 'edx, -1', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1127, 'asm_x86_mov_esi_1_exact', 'esi, 1', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1128, 'asm_x86_mov_r8d_minus_one_exact', 'r8d, 0xFFFFFFFF', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1129, 'asm_x86_mov_rdx_1_exact', 'rdx, 1', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1130, 'asm_x86_mov_rdx_is_exact', 'rdx, IS', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1131, 'asm_x86_mov_rdx_is4_exact', 'rdx, IS*4', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1132, 'asm_x86_mov_rdx_rs_exact', 'rdx, RS', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1133, 'asm_x86_mov_rdx_vs_exact', 'rdx, VS', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1134, 'asm_x86_mov_rdx_vs4_exact', 'rdx, VS*4', 0),
  (3, 'movd', null, 'kernel/x86_64/object/instruction/x86_64/movd.erobj', null, 1135, 'asm_x86_movd_eax_xmm0_exact', 'eax, xmm0', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1136, 'asm_x86_mov_eax_0x3e800000_exact', 'eax, 0x3E800000', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1137, 'asm_x86_mov_eax_0x3f400000_exact', 'eax, 0x3F400000', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1138, 'asm_x86_mov_eax_0x41800000_exact', 'eax, 0x41800000', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1139, 'asm_x86_mov_eax_0x42000000_exact', 'eax, 0x42000000', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1140, 'asm_x86_mov_ecx_minus_one_exact', 'ecx, 0xFFFFFFFF', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1141, 'asm_x86_mov_edi_0_exact', 'edi, 0', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1142, 'asm_x86_mov_edi_255_exact', 'edi, 255', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1143, 'asm_x86_mov_edi_7_exact', 'edi, 7', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1144, 'asm_x86_mov_edx_minus_two_exact', 'edx, -2', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1145, 'asm_x86_mov_edx_255_exact', 'edx, 255', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1146, 'asm_x86_mov_esi_2_exact', 'esi, 2', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1147, 'asm_x86_mov_esi_5_exact', 'esi, 5', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1147, 'asm_x86_mov_esi_da_wasm_a_len_exact', 'esi, DA_WASM_A_LEN', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1147, 'asm_x86_mov_esi_da_wasm_b_len_exact', 'esi, DA_WASM_B_LEN', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1148, 'asm_x86_mov_r9d_42_exact', 'r9d, 42', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1149, 'asm_x86_mov_rdx_minus_two_exact', 'rdx, -2', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1150, 'asm_x86_mov_rdx_4_exact', 'rdx, 4', 0),
  (3, 'movd', null, 'kernel/x86_64/object/instruction/x86_64/movd.erobj', null, 1151, 'asm_x86_movd_xmm0_eax_exact', 'xmm0, eax', 0),
  (3, 'movd', null, 'kernel/x86_64/object/instruction/x86_64/movd.erobj', null, 1152, 'asm_x86_movd_xmm1_eax_exact', 'xmm1, eax', 0);

insert or ignore into asm_dsl_rule(line_kind, op_name, operation_kind_id, instruction_path, form_path, encoding_id, rule_name, exact_operand_text, flags) values
  (3, 'dec', null, 'kernel/x86_64/object/instruction/x86_64/dec.erobj', null, 1153, 'asm_x86_dec_ecx_exact', 'ecx', 0),
  (3, 'dec', null, 'kernel/x86_64/object/instruction/x86_64/dec.erobj', null, 1154, 'asm_x86_dec_eax_exact', 'eax', 0);

insert or ignore into asm_dsl_rule(line_kind, op_name, operation_kind_id, instruction_path, form_path, encoding_id, rule_name, exact_operand_text, flags) values
  (3, 'default', null, null, null, null, 'default_rel_metadata', 'rel', 1),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1155, 'asm_x86_mov_edx_unexpected_ntor_stub_exit_exact', 'edx, UNEXPECTED_NTOR_STUB_EXIT', 0);

insert or ignore into asm_dsl_rule(line_kind, op_name, operation_kind_id, instruction_path, form_path, encoding_id, rule_name, exact_operand_text, flags) values
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1156, 'asm_x86_mov_edx_1_exact', 'edx, 1', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1157, 'asm_x86_mov_ecx_1_exact', 'ecx, 1', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1158, 'asm_x86_mov_edi_1_exact', 'edi, 1', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1159, 'asm_x86_mov_r12d_edi_exact', 'r12d, edi', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1160, 'asm_x86_mov_rbp_rsp_exact', 'rbp, rsp', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1161, 'asm_x86_mov_r12_rsi_exact', 'r12, rsi', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1162, 'asm_x86_cmp_eax_1_exact', 'eax, 1', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1163, 'asm_x86_mov_r15_rcx_exact', 'r15, rcx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1164, 'asm_x86_mov_r15d_ecx_exact', 'r15d, ecx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1165, 'asm_x86_mov_eax_r11d_exact', 'eax, r11d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1166, 'asm_x86_mov_edx_2_exact', 'edx, 2', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1167, 'asm_x86_mov_edx_32_exact', 'edx, 32', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1168, 'asm_x86_mov_rax_rdi_exact', 'rax, rdi', 0),
  (3, 'xor', null, 'kernel/x86_64/object/instruction/x86_64/xor.erobj', null, 1169, 'asm_x86_xor_r15d_r15d_exact', 'r15d, r15d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1170, 'asm_x86_mov_rdx_r13_exact', 'rdx, r13', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1171, 'asm_x86_mov_esi_ebx_exact', 'esi, ebx', 0),
  (3, 'xor', null, 'kernel/x86_64/object/instruction/x86_64/xor.erobj', null, 1172, 'asm_x86_xor_r10d_r10d_exact', 'r10d, r10d', 0),
  (3, 'or', null, 'kernel/x86_64/object/instruction/x86_64/or.erobj', null, 1173, 'asm_x86_or_eax_ecx_exact', 'eax, ecx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1174, 'asm_x86_mov_edx_r14d_exact', 'edx, r14d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1175, 'asm_x86_mov_esi_r14d_exact', 'esi, r14d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1176, 'asm_x86_mov_ebx_edx_exact', 'ebx, edx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1177, 'asm_x86_mov_r14_rcx_exact', 'r14, rcx', 0),
  (3, 'xor', null, 'kernel/x86_64/object/instruction/x86_64/xor.erobj', null, 1178, 'asm_x86_xor_r14d_r14d_exact', 'r14d, r14d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1179, 'asm_x86_mov_eax_edx_exact', 'eax, edx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1180, 'asm_x86_mov_ebx_esi_exact', 'ebx, esi', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1181, 'asm_x86_mov_r14d_eax_exact', 'r14d, eax', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1182, 'asm_x86_mov_eax_r8d_exact', 'eax, r8d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1183, 'asm_x86_mov_rdi_ptr_al_exact', '[rdi], al', 0),
  (3, 'xor', null, 'kernel/x86_64/object/instruction/x86_64/xor.erobj', null, 1184, 'asm_x86_xor_r11d_r11d_exact', 'r11d, r11d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1185, 'asm_x86_mov_r8d_eax_exact', 'r8d, eax', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1186, 'asm_x86_mov_r13d_edx_exact', 'r13d, edx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1187, 'asm_x86_mov_ecx_r15d_exact', 'ecx, r15d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1188, 'asm_x86_mov_ecx_ebx_exact', 'ecx, ebx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1189, 'asm_x86_mov_edx_r13d_exact', 'edx, r13d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1190, 'asm_x86_mov_r8d_1_exact', 'r8d, 1', 0),
  (3, 'or', null, 'kernel/x86_64/object/instruction/x86_64/or.erobj', null, 1191, 'asm_x86_or_eax_edx_exact', 'eax, edx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1192, 'asm_x86_mov_ecx_r14d_exact', 'ecx, r14d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1193, 'asm_x86_mov_r12_rdx_exact', 'r12, rdx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1194, 'asm_x86_mov_r15d_eax_exact', 'r15d, eax', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1195, 'asm_x86_mov_r15_r8_exact', 'r15, r8', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1196, 'asm_x86_mov_edx_r15d_exact', 'edx, r15d', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1197, 'asm_x86_cmp_eax_2_exact', 'eax, 2', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1198, 'asm_x86_mov_rdx_r15_exact', 'rdx, r15', 0),
  (3, 'test', null, 'kernel/x86_64/object/instruction/x86_64/test.erobj', null, 1199, 'asm_x86_test_ecx_ecx_exact', 'ecx, ecx', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1200, 'asm_x86_cmp_eax_ecx_exact', 'eax, ecx', 0),
  (3, 'div', null, 'kernel/x86_64/object/instruction/x86_64/div.erobj', null, 1201, 'asm_x86_div_ecx_exact', 'ecx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1202, 'asm_x86_mov_r13_rcx_exact', 'r13, rcx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1203, 'asm_x86_mov_rbx_r8_exact', 'rbx, r8', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1204, 'asm_x86_mov_rcx_r15_exact', 'rcx, r15', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1205, 'asm_x86_mov_rdx_rsp_exact', 'rdx, rsp', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1206, 'asm_x86_mov_edi_eax_exact', 'edi, eax', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1207, 'asm_x86_mov_r12d_esi_exact', 'r12d, esi', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1208, 'asm_x86_mov_esi_3_exact', 'esi, 3', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1209, 'asm_x86_mov_ecx_2_exact', 'ecx, 2', 0),
  (3, 'test', null, 'kernel/x86_64/object/instruction/x86_64/test.erobj', null, 1210, 'asm_x86_test_r14d_r14d_exact', 'r14d, r14d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1211, 'asm_x86_mov_r12d_eax_exact', 'r12d, eax', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1212, 'asm_x86_mov_ebx_1_exact', 'ebx, 1', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1213, 'asm_x86_mov_edx_r8d_exact', 'edx, r8d', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1214, 'asm_x86_cmp_eax_r13d_exact', 'eax, r13d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1215, 'asm_x86_mov_r10d_eax_exact', 'r10d, eax', 0),
  (3, 'test', null, 'kernel/x86_64/object/instruction/x86_64/test.erobj', null, 1216, 'asm_x86_test_r15d_r15d_exact', 'r15d, r15d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1217, 'asm_x86_mov_r15d_r8d_exact', 'r15d, r8d', 0),
  (3, 'xor', null, 'kernel/x86_64/object/instruction/x86_64/xor.erobj', null, 1218, 'asm_x86_xor_r12d_r12d_exact', 'r12d, r12d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1219, 'asm_x86_mov_r11d_eax_exact', 'r11d, eax', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1220, 'asm_x86_mov_r15_rax_exact', 'r15, rax', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1221, 'asm_x86_add_rsp_48_exact', 'rsp, 48', 0),
  (3, 'sub', null, 'kernel/x86_64/object/instruction/x86_64/sub.erobj', null, 1222, 'asm_x86_sub_eax_ebx_exact', 'eax, ebx', 0),
  (3, 'shl', null, 'kernel/x86_64/object/instruction/x86_64/shl.erobj', null, 1223, 'asm_x86_shl_eax_cl_exact', 'eax, cl', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1224, 'asm_x86_mov_ebx_edi_exact', 'ebx, edi', 0),
  (3, 'xor', null, 'kernel/x86_64/object/instruction/x86_64/xor.erobj', null, 1225, 'asm_x86_xor_r13d_r13d_exact', 'r13d, r13d', 0),
  (3, 'sub', null, 'kernel/x86_64/object/instruction/x86_64/sub.erobj', null, 1226, 'asm_x86_sub_rsp_16_exact', 'rsp, 16', 0),
  (3, 'shr', null, 'kernel/x86_64/object/instruction/x86_64/shr.erobj', null, 1227, 'asm_x86_shr_eax_8_exact', 'eax, 8', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1228, 'asm_x86_mov_eax_r12d_exact', 'eax, r12d', 0),
  (3, 'rep', null, 'kernel/x86_64/object/instruction/x86_64/rep.erobj', null, 1229, 'asm_x86_rep_movsb_exact', 'movsb', 0),
  (3, 'push', null, 'kernel/x86_64/object/instruction/x86_64/push.erobj', null, 1230, 'asm_x86_push_rdi_exact', 'rdi', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1231, 'asm_x86_mov_rsi_rax_exact', 'rsi, rax', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1232, 'asm_x86_mov_edx_ecx_exact', 'edx, ecx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1233, 'asm_x86_mov_r14d_ecx_exact', 'r14d, ecx', 0),
  (3, 'pop', null, 'kernel/x86_64/object/instruction/x86_64/pop.erobj', null, 1234, 'asm_x86_pop_rdi_exact', 'rdi', 0),
  (3, 'shl', null, 'kernel/x86_64/object/instruction/x86_64/shl.erobj', null, 1235, 'asm_x86_shl_eax_2_exact', 'eax, 2', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1236, 'asm_x86_mov_rsi_rdi_exact', 'rsi, rdi', 0),
  (3, 'shl', null, 'kernel/x86_64/object/instruction/x86_64/shl.erobj', null, 1237, 'asm_x86_shl_eax_1_exact', 'eax, 1', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1238, 'asm_x86_mov_eax_r9d_exact', 'eax, r9d', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1239, 'asm_x86_cmp_eax_ebx_exact', 'eax, ebx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1240, 'asm_x86_mov_rdi_rdx_exact', 'rdi, rdx', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1241, 'asm_x86_cmp_eax_r14d_exact', 'eax, r14d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1242, 'asm_x86_mov_rdx_rsi_exact', 'rdx, rsi', 0),
  (3, 'test', null, 'kernel/x86_64/object/instruction/x86_64/test.erobj', null, 1243, 'asm_x86_test_r8d_r8d_exact', 'r8d, r8d', 0),
  (3, 'movzx', null, 'kernel/x86_64/object/instruction/x86_64/movzx.erobj', null, 1244, 'asm_x86_movzx_eax_byte_rdi_ptr_exact', 'eax, byte [rdi]', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1245, 'asm_x86_mov_rsi_rbx_exact', 'rsi, rbx', 0),
  (3, 'sub', null, 'kernel/x86_64/object/instruction/x86_64/sub.erobj', null, 1246, 'asm_x86_sub_eax_ecx_exact', 'eax, ecx', 0),
  (3, 'dec', null, 'kernel/x86_64/object/instruction/x86_64/dec.erobj', null, 1247, 'asm_x86_dec_r14d_exact', 'r14d', 0),
  (3, 'shr', null, 'kernel/x86_64/object/instruction/x86_64/shr.erobj', null, 1248, 'asm_x86_shr_eax_3_exact', 'eax, 3', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1249, 'asm_x86_mov_ebx_r8d_exact', 'ebx, r8d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1250, 'asm_x86_mov_esi_r15d_exact', 'esi, r15d', 0),
  (3, 'shl', null, 'kernel/x86_64/object/instruction/x86_64/shl.erobj', null, 1251, 'asm_x86_shl_eax_3_exact', 'eax, 3', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1252, 'asm_x86_mov_rdx_r12_exact', 'rdx, r12', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1253, 'asm_x86_cmp_eax_r12d_exact', 'eax, r12d', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1254, 'asm_x86_add_eax_r13d_exact', 'eax, r13d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1255, 'asm_x86_mov_r9d_eax_exact', 'r9d, eax', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1256, 'asm_x86_mov_al_rdi_ptr_exact', 'al, [rdi]', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1257, 'asm_x86_mov_edx_3_exact', 'edx, 3', 0),
  (3, 'lea', null, 'kernel/x86_64/object/instruction/x86_64/lea.erobj', null, 1258, 'asm_x86_lea_rdi_r12_rax_exact', 'rdi, [r12 + rax]', 0),
  (3, 'inc', null, 'kernel/x86_64/object/instruction/x86_64/inc.erobj', null, 1259, 'asm_x86_inc_r12d_exact', 'r12d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1260, 'asm_x86_mov_r15d_edx_exact', 'r15d, edx', 0),
  (3, 'dec', null, 'kernel/x86_64/object/instruction/x86_64/dec.erobj', null, 1261, 'asm_x86_dec_r13d_exact', 'r13d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1262, 'asm_x86_mov_rsp_24_rax_exact', '[rsp + 24], rax', 0),
  (3, 'push', null, 'kernel/x86_64/object/instruction/x86_64/push.erobj', null, 1263, 'asm_x86_push_r10_exact', 'r10', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1264, 'asm_x86_cmp_eax_esi_exact', 'eax, esi', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1265, 'asm_x86_add_eax_r15d_exact', 'eax, r15d', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1266, 'asm_x86_cmp_eax_edx_exact', 'eax, edx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1267, 'asm_x86_mov_r14_r8_exact', 'r14, r8', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1268, 'asm_x86_cmp_eax_0_exact', 'eax, 0', 0),
  (3, 'shl', null, 'kernel/x86_64/object/instruction/x86_64/shl.erobj', null, 1269, 'asm_x86_shl_eax_16_exact', 'eax, 16', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1270, 'asm_x86_mov_r12_rax_exact', 'r12, rax', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1271, 'asm_x86_mov_edx_16_exact', 'edx, 16', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1272, 'asm_x86_mov_cl_1_exact', 'cl, 1', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1273, 'asm_x86_mov_r14_rax_exact', 'r14, rax', 0),
  (3, 'in', null, 'kernel/x86_64/object/instruction/x86_64/in.erobj', null, 1274, 'asm_x86_in_al_dx_exact', 'al, dx', 0),
  (3, 'out', null, 'kernel/x86_64/object/instruction/x86_64/out.erobj', null, 1275, 'asm_x86_out_dx_al_exact', 'dx, al', 0),
  (3, 'pop', null, 'kernel/x86_64/object/instruction/x86_64/pop.erobj', null, 1276, 'asm_x86_pop_rdx_exact', 'rdx', 0),
  (3, 'pop', null, 'kernel/x86_64/object/instruction/x86_64/pop.erobj', null, 1277, 'asm_x86_pop_rsi_exact', 'rsi', 0),
  (3, 'push', null, 'kernel/x86_64/object/instruction/x86_64/push.erobj', null, 1278, 'asm_x86_push_rdx_exact', 'rdx', 0),
  (3, 'push', null, 'kernel/x86_64/object/instruction/x86_64/push.erobj', null, 1279, 'asm_x86_push_r8_exact', 'r8', 0),
  (3, 'push', null, 'kernel/x86_64/object/instruction/x86_64/push.erobj', null, 1280, 'asm_x86_push_rsi_exact', 'rsi', 0),
  (3, 'movzx', null, 'kernel/x86_64/object/instruction/x86_64/movzx.erobj', null, 1281, 'asm_x86_movzx_eax_al_exact', 'eax, al', 0),
  (3, 'shr', null, 'kernel/x86_64/object/instruction/x86_64/shr.erobj', null, 1282, 'asm_x86_shr_eax_16_exact', 'eax, 16', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1283, 'asm_x86_cmp_eax_0xffffffff_exact', 'eax, 0xFFFFFFFF', 0),
  (3, 'pop', null, 'kernel/x86_64/object/instruction/x86_64/pop.erobj', null, 1284, 'asm_x86_pop_r8_exact', 'r8', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1285, 'asm_x86_mov_rdx_rax_exact', 'rdx, rax', 0),
  (3, 'sub', null, 'kernel/x86_64/object/instruction/x86_64/sub.erobj', null, 1286, 'asm_x86_sub_rsp_8_exact', 'rsp, 8', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1287, 'asm_x86_mov_ecx_8_exact', 'ecx, 8', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1288, 'asm_x86_mov_r13d_eax_exact', 'r13d, eax', 0),
  (3, 'rep', null, 'kernel/x86_64/object/instruction/x86_64/rep.erobj', null, 1289, 'asm_x86_rep_stosb_exact', 'stosb', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1290, 'asm_x86_mov_rdx_rbx_exact', 'rdx, rbx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1291, 'asm_x86_mov_edi_2_exact', 'edi, 2', 0),
  (3, 'push', null, 'kernel/x86_64/object/instruction/x86_64/push.erobj', null, 1292, 'asm_x86_push_r9_exact', 'r9', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1293, 'asm_x86_mov_ecx_16_exact', 'ecx, 16', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1294, 'asm_x86_mov_ecx_3_exact', 'ecx, 3', 0),
  (3, 'sub', null, 'kernel/x86_64/object/instruction/x86_64/sub.erobj', null, 1295, 'asm_x86_sub_rsp_32_exact', 'rsp, 32', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1296, 'asm_x86_mov_eax_r10d_exact', 'eax, r10d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1297, 'asm_x86_mov_rsi_rsp_exact', 'rsi, rsp', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1298, 'asm_x86_mov_rdi_rsi_exact', 'rdi, rsi', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1299, 'asm_x86_mov_r8_rdi_exact', 'r8, rdi', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1300, 'asm_x86_mov_ecx_esi_exact', 'ecx, esi', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/arm32/mov.erobj', null, 1301, 'asm_arm32_mov_r0_0_exact', 'r0, #0', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/arm32/cmp.erobj', null, 1302, 'asm_arm32_cmp_r0_0_exact', 'r0, #0', 0),
  (3, 'bx', null, 'kernel/x86_64/object/instruction/arm32/bx.erobj', null, 60, 'asm_arm32_bx_lr_exact', 'lr', 0),
  (3, 'pop', null, 'kernel/x86_64/object/instruction/arm32/pop.erobj', null, 1304, 'asm_arm32_pop_pc_exact', '{pc}', 0),
  (3, 'push', null, 'kernel/x86_64/object/instruction/arm32/push.erobj', null, 1305, 'asm_arm32_push_lr_exact', '{lr}', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/arm32/mov.erobj', null, 1306, 'asm_arm32_mov_r1_0_exact', 'r1, #0', 0),
  (3, 'pop', null, 'kernel/x86_64/object/instruction/arm32/pop.erobj', null, 1307, 'asm_arm32_pop_r4_pc_exact', '{r4, pc}', 0),
  (3, 'push', null, 'kernel/x86_64/object/instruction/arm32/push.erobj', null, 1308, 'asm_arm32_push_r4_lr_exact', '{r4, lr}', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/arm32/mov.erobj', null, 1309, 'asm_arm32_mov_r0_1_exact', 'r0, #1', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1310, 'asm_x86_mov_esi_4_exact', 'esi, 4', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1311, 'asm_x86_mov_rax_r12_exact', 'rax, r12', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1312, 'asm_x86_mov_r8_rax_exact', 'r8, rax', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1313, 'asm_x86_mov_rbx_rsi_exact', 'rbx, rsi', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1124, 'asm_x86_mov_ecx_4_exact', 'ecx, 4', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1315, 'asm_x86_cmp_ebx_r13d_exact', 'ebx, r13d', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1316, 'asm_x86_cmp_eax_3_exact', 'eax, 3', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1317, 'asm_x86_mov_edx_64_exact', 'edx, 64', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1318, 'asm_x86_mov_rbx_rdx_exact', 'rbx, rdx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1319, 'asm_x86_mov_rax_r13_exact', 'rax, r13', 0),
  (3, 'dec', null, 'kernel/x86_64/object/instruction/x86_64/dec.erobj', null, 1320, 'asm_x86_dec_ebx_exact', 'ebx', 0),
  (3, 'pop', null, 'kernel/x86_64/object/instruction/x86_64/pop.erobj', null, 1321, 'asm_x86_pop_r9_exact', 'r9', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1322, 'asm_x86_mov_ecx_64_exact', 'ecx, 64', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1323, 'asm_x86_mov_rcx_r14_exact', 'rcx, r14', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1324, 'asm_x86_mov_edi_r13d_exact', 'edi, r13d', 0),
  (3, 'pop', null, 'kernel/x86_64/object/instruction/x86_64/pop.erobj', null, 1325, 'asm_x86_pop_r10_exact', 'r10', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1326, 'asm_x86_mov_rdi_ptr_eax_exact', '[rdi], eax', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1327, 'asm_x86_mov_rdi_ptr_rax_exact', '[rdi], rax', 0),
  (3, 'dec', null, 'kernel/x86_64/object/instruction/x86_64/dec.erobj', null, 1328, 'asm_x86_dec_rcx_exact', 'rcx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1329, 'asm_x86_mov_rcx_r13_exact', 'rcx, r13', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1330, 'asm_x86_mov_ecx_r8d_exact', 'ecx, r8d', 0),
  (3, 'lea', null, 'kernel/x86_64/object/instruction/x86_64/lea.erobj', null, 1331, 'asm_x86_lea_rdi_rsp_exact', 'rdi, [rsp]', 0),
  (3, 'sub', null, 'kernel/x86_64/object/instruction/x86_64/sub.erobj', null, 1332, 'asm_x86_sub_rsp_64_exact', 'rsp, 64', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1333, 'asm_x86_mov_rax_r15_exact', 'rax, r15', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1334, 'asm_x86_cmp_edx_error_no_data_exact', 'edx, ERROR_NO_DATA', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1335, 'asm_x86_mov_r8d_edx_exact', 'r8d, edx', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1336, 'asm_x86_cmp_edx_error_unsupported_exact', 'edx, ERROR_UNSUPPORTED', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1337, 'asm_x86_cmp_edx_error_corrupt_exact', 'edx, ERROR_CORRUPT', 0),
  (3, 'dec', null, 'kernel/x86_64/object/instruction/x86_64/dec.erobj', null, 1338, 'asm_x86_dec_r15d_exact', 'r15d', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1339, 'asm_x86_cmp_rax_rcx_exact', 'rax, rcx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1340, 'asm_x86_mov_rdi_ptr_byte_0_exact', 'byte [rdi], 0', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1341, 'asm_x86_mov_rax_r8_exact', 'rax, r8', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1342, 'asm_x86_add_dl_ascii_0_exact', 'dl, ''0''', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1343, 'asm_x86_mov_r13_rax_exact', 'r13, rax', 0),
  (3, 'test', null, 'kernel/x86_64/object/instruction/x86_64/test.erobj', null, 1344, 'asm_x86_test_al_al_exact', 'al, al', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1345, 'asm_x86_mov_rax_r11_exact', 'rax, r11', 0),
  (3, 'xor', null, 'kernel/x86_64/object/instruction/x86_64/xor.erobj', null, 1346, 'asm_x86_xor_rdx_rdx_exact', 'rdx, rdx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1347, 'asm_x86_mov_rcx_rdx_exact', 'rcx, rdx', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1348, 'asm_x86_cmp_rax_rdx_exact', 'rax, rdx', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1349, 'asm_x86_add_eax_r14d_exact', 'eax, r14d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1350, 'asm_x86_mov_edi_r15d_exact', 'edi, r15d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1351, 'asm_x86_mov_ebx_ecx_exact', 'ebx, ecx', 0),
  (3, 'dec', null, 'kernel/x86_64/object/instruction/x86_64/dec.erobj', null, 1352, 'asm_x86_dec_edx_exact', 'edx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1353, 'asm_x86_mov_edx_4_exact', 'edx, 4', 0),
  (3, 'shl', null, 'kernel/x86_64/object/instruction/x86_64/shl.erobj', null, 1354, 'asm_x86_shl_eax_8_exact', 'eax, 8', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1355, 'asm_x86_add_rsp_64_exact', 'rsp, 64', 0),
  (3, 'test', null, 'kernel/x86_64/object/instruction/x86_64/test.erobj', null, 1356, 'asm_x86_test_r15_r15_exact', 'r15, r15', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1357, 'asm_x86_cmp_eax_4_exact', 'eax, 4', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1358, 'asm_x86_mov_edx_r9d_exact', 'edx, r9d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1359, 'asm_x86_mov_al_rsi_ptr_exact', 'al, [rsi]', 0),
  (3, 'dec', null, 'kernel/x86_64/object/instruction/x86_64/dec.erobj', null, 1360, 'asm_x86_dec_rax_exact', 'rax', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1361, 'asm_x86_mov_rax_minus_1_exact', 'rax, -1', 0),
  (3, 'pause', null, 'kernel/x86_64/object/instruction/x86_64/pause.erobj', null, 1362, 'asm_x86_pause_exact', '', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1363, 'asm_x86_mov_esi_edx_exact', 'esi, edx', 0),
  (3, 'shl', null, 'kernel/x86_64/object/instruction/x86_64/shl.erobj', null, 1364, 'asm_x86_shl_ecx_3_exact', 'ecx, 3', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1365, 'asm_x86_mov_eax_rsp_ptr_exact', 'eax, [rsp]', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1366, 'asm_x86_mov_rax_rsp_ptr_exact', 'rax, [rsp]', 0),
  (3, 'pop', null, 'kernel/x86_64/object/instruction/x86_64/pop.erobj', null, 1367, 'asm_x86_pop_r11_exact', 'r11', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1368, 'asm_x86_mov_r13d_ecx_exact', 'r13d, ecx', 0),
  (3, 'inc', null, 'kernel/x86_64/object/instruction/x86_64/inc.erobj', null, 1369, 'asm_x86_inc_r15_exact', 'r15', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1370, 'asm_x86_mov_rcx_rax_exact', 'rcx, rax', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1371, 'asm_x86_mov_esi_7_exact', 'esi, 7', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1372, 'asm_x86_cmp_al_10_exact', 'al, 10', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1373, 'asm_x86_mov_esi_8_exact', 'esi, 8', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1374, 'asm_x86_mov_rax_rbx_exact', 'rax, rbx', 0),
  (3, 'mul', null, 'kernel/x86_64/object/instruction/x86_64/mul.erobj', null, 1375, 'asm_x86_mul_ecx_exact', 'ecx', 0),
  (3, 'bswap', null, 'kernel/x86_64/object/instruction/x86_64/bswap.erobj', null, 1376, 'asm_x86_bswap_eax_exact', 'eax', 0),
  (3, 'inc', null, 'kernel/x86_64/object/instruction/x86_64/inc.erobj', null, 1377, 'asm_x86_inc_r11_exact', 'r11', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1378, 'asm_x86_mov_r10_rax_exact', 'r10, rax', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1379, 'asm_x86_cmp_ecx_esi_exact', 'ecx, esi', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1380, 'asm_x86_mov_rax_rsi_exact', 'rax, rsi', 0),
  (3, 'dec', null, 'kernel/x86_64/object/instruction/x86_64/dec.erobj', null, 1381, 'asm_x86_dec_rbx_exact', 'rbx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1382, 'asm_x86_mov_esi_16_exact', 'esi, 16', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1383, 'asm_x86_mov_rsi_r9_exact', 'rsi, r9', 0);

insert or ignore into asm_dsl_rule(line_kind, op_name, operation_kind_id, instruction_path, form_path, encoding_id, rule_name, exact_operand_text, flags) values
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1384, 'asm_x86_cmp_rdx_error_recursion_exact', 'rdx, ERROR_RECURSION', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1385, 'asm_x86_mov_eax_sys_write_exact', 'eax, SYS_write', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1386, 'asm_x86_mov_eax_sys_close_exact', 'eax, SYS_close', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1387, 'asm_x86_mov_rsi_rdx_exact', 'rsi, rdx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1388, 'asm_x86_mov_esi_32_exact', 'esi, 32', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1389, 'asm_x86_mov_r12_rsp_ptr_exact', 'r12, [rsp]', 0),
  (3, 'shr', null, 'kernel/x86_64/object/instruction/x86_64/shr.erobj', null, 1390, 'asm_x86_shr_eax_24_exact', 'eax, 24', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1391, 'asm_x86_add_r15_rax_exact', 'r15, rax', 0),
  (3, 'test', null, 'kernel/x86_64/object/instruction/x86_64/test.erobj', null, 1392, 'asm_x86_test_r13d_r13d_exact', 'r13d, r13d', 0),
  (3, 'sub', null, 'kernel/x86_64/object/instruction/x86_64/sub.erobj', null, 1393, 'asm_x86_sub_ecx_eax_exact', 'ecx, eax', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1394, 'asm_x86_mov_rsp_ptr_eax_exact', '[rsp], eax', 0),
  (3, 'test', null, 'kernel/x86_64/object/instruction/x86_64/test.erobj', null, 1395, 'asm_x86_test_ebx_ebx_exact', 'ebx, ebx', 0),
  (3, 'shr', null, 'kernel/x86_64/object/instruction/x86_64/shr.erobj', null, 1396, 'asm_x86_shr_eax_4_exact', 'eax, 4', 0),
  (3, 'push', null, 'kernel/x86_64/object/instruction/x86_64/push.erobj', null, 1397, 'asm_x86_push_r11_exact', 'r11', 0),
  (3, 'shr', null, 'kernel/x86_64/object/instruction/x86_64/shr.erobj', null, 1398, 'asm_x86_shr_eax_1_exact', 'eax, 1', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1399, 'asm_x86_mov_eax_2_exact', 'eax, 2', 0),
  (3, 'test', null, 'kernel/x86_64/object/instruction/x86_64/test.erobj', null, 1400, 'asm_x86_test_r9d_r9d_exact', 'r9d, r9d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1401, 'asm_x86_mov_esi_128_exact', 'esi, 128', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1402, 'asm_x86_mov_edx_r12d_exact', 'edx, r12d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1403, 'asm_x86_mov_r8d_2_exact', 'r8d, 2', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1404, 'asm_x86_mov_edx_8_exact', 'edx, 8', 0);

insert or ignore into asm_dsl_rule(line_kind, op_name, operation_kind_id, instruction_path, form_path, encoding_id, rule_name, exact_operand_text, flags) values
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1405, 'asm_x86_mov_rdi_0x1234_exact', 'rdi, 0x1234', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1406, 'asm_x86_mov_r9d_2_exact', 'r9d, 2', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1407, 'asm_x86_mov_esi_2500_exact', 'esi, 2500', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1408, 'asm_x86_mov_rdi_1_exact', 'rdi, 1', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1409, 'asm_x86_mov_rdx_37_exact', 'rdx, 37', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1410, 'asm_x86_mov_rax_1_exact', 'rax, 1', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1411, 'asm_x86_mov_eax_0x0100000a_exact', 'eax, 0x0100000a', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1412, 'asm_x86_mov_eax_12_exact', 'eax, 12', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1413, 'asm_x86_mov_rdx_ptr_0x01020304_exact', 'dword [rdx], 0x01020304', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1414, 'asm_x86_mov_eax_4_exact', 'eax, 4', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1415, 'asm_x86_mov_dx_0xf4_exact', 'dx, 0xf4', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1416, 'asm_x86_mov_eax_unexpected_http_stub_exit_exact', 'eax, UNEXPECTED_HTTP_STUB_EXIT', 0),
  (3, 'out', null, 'kernel/x86_64/object/instruction/x86_64/out.erobj', null, 1417, 'asm_x86_out_dx_eax_exact', 'dx, eax', 0),
  (3, 'cli', null, 'kernel/x86_64/object/instruction/x86_64/cli.erobj', null, 1418, 'asm_x86_cli_exact', '', 0),
  (3, 'hlt', null, 'kernel/x86_64/object/instruction/x86_64/hlt.erobj', null, 1419, 'asm_x86_hlt_exact', '', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1420, 'asm_x86_mov_edi_unexpected_http_stub_exit_exact', 'edi, UNEXPECTED_HTTP_STUB_EXIT', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1421, 'asm_x86_mov_eax_sys_exit_exact', 'eax, SYS_EXIT', 0);

insert or ignore into asm_dsl_rule(line_kind, op_name, operation_kind_id, instruction_path, form_path, encoding_id, rule_name, exact_operand_text, flags) values
  (3, 'lea', null, 'kernel/x86_64/object/instruction/x86_64/lea.erobj', null, 1422, 'asm_x86_lea_rdi_r12_rbx_exact', 'rdi, [r12 + rbx]', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1423, 'asm_x86_mov_rdi_r13_plus_8_ptr_exact', 'rdi, [r13 + 8]', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1424, 'asm_x86_mov_al_0x0f_exact', 'al, 0x0F', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1425, 'asm_x86_mov_al_0x48_exact', 'al, 0x48', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1426, 'asm_x86_cmp_edx_error_invalid_param_exact', 'edx, ERROR_INVALID_PARAM', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1427, 'asm_x86_mov_ecx_rsp_plus_40_ptr_exact', 'ecx, [rsp + 40]', 0),
  (3, 'test', null, 'kernel/x86_64/object/instruction/x86_64/test.erobj', null, 1428, 'asm_x86_test_rcx_rcx_exact', 'rcx, rcx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1399, 'asm_x86_mov_eax_sys_open_exact', 'eax, SYS_open', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1429, 'asm_x86_mov_rsp_plus_8_ptr_rax_exact', '[rsp + 8], rax', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1430, 'asm_x86_mov_edi_10_exact', 'edi, 10', 0),
  (3, 'or', null, 'kernel/x86_64/object/instruction/x86_64/or.erobj', null, 1431, 'asm_x86_or_rax_rdx_exact', 'rax, rdx', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1432, 'asm_x86_cmp_eax_minus_1_exact', 'eax, -1', 0),
  (3, 'test', null, 'kernel/x86_64/object/instruction/x86_64/test.erobj', null, 1433, 'asm_x86_test_esi_esi_exact', 'esi, esi', 0),
  (3, 'sub', null, 'kernel/x86_64/object/instruction/x86_64/sub.erobj', null, 1434, 'asm_x86_sub_esi_ebx_exact', 'esi, ebx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1435, 'asm_x86_mov_edx_error_parse_exact', 'edx, ERROR_PARSE', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1115, 'asm_x86_mov_ecx_32_exact', 'ecx, 32', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1436, 'asm_x86_mov_rsp_ptr_rax_exact', '[rsp], rax', 0),
  (3, 'and', null, 'kernel/x86_64/object/instruction/x86_64/and.erobj', null, 1437, 'asm_x86_and_edi_0xff_exact', 'edi, 0xFF', 0),
  (3, 'push', null, 'kernel/x86_64/object/instruction/x86_64/push.erobj', null, 1438, 'asm_x86_push_2_exact', '2', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1439, 'asm_x86_cmp_ecx_r12d_exact', 'ecx, r12d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1440, 'asm_x86_mov_dx_di_exact', 'dx, di', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1441, 'asm_x86_cmp_rax_42_exact', 'rax, 42', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1442, 'asm_x86_mov_cl_2_exact', 'cl, 2', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1443, 'asm_x86_mov_rdi_r13_rbx8_ptr_exact', 'rdi, [r13 + rbx * 8]', 0),
  (3, 'shl', null, 'kernel/x86_64/object/instruction/x86_64/shl.erobj', null, 1444, 'asm_x86_shl_rdx_32_exact', 'rdx, 32', 0),
  (3, 'test', null, 'kernel/x86_64/object/instruction/x86_64/test.erobj', null, 1445, 'asm_x86_test_r8_r8_exact', 'r8, r8', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1446, 'asm_x86_mov_sil_space_exact', 'sil, '' ''', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1447, 'asm_x86_mov_al_0xc0_exact', 'al, 0xC0', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1448, 'asm_x86_mov_eax_sys_read_exact', 'eax, SYS_read', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1449, 'asm_x86_mov_r8d_32_exact', 'r8d, 32', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1450, 'asm_x86_mov_esi_256_exact', 'esi, 256', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1451, 'asm_x86_mov_eax_sys_exit_group_exact', 'eax, SYS_exit_group', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1146, 'asm_x86_mov_esi_vp8_bool_initial_bytes_exact', 'esi, VP8_BOOL_INITIAL_BYTES', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1452, 'asm_x86_add_r8_decoded_op_size_exact', 'r8, DECODED_OP_SIZE', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/arm32/cmp.erobj', null, 1453, 'asm_arm32_cmp_r0_r1_exact', 'r0, r1', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/arm32/cmp.erobj', null, 1454, 'asm_arm32_cmp_r0_1_exact', 'r0, #1', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/arm32/cmp.erobj', null, 1455, 'asm_arm32_cmp_r0_r2_exact', 'r0, r2', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/arm32/cmp.erobj', null, 1456, 'asm_arm32_cmp_r0_r3_exact', 'r0, r3', 0),
  (3, 'pop', null, 'kernel/x86_64/object/instruction/arm32/pop.erobj', null, 1457, 'asm_arm32_pop_r4_r5_pc_exact', '{r4, r5, pc}', 0),
  (3, 'push', null, 'kernel/x86_64/object/instruction/arm32/push.erobj', null, 1458, 'asm_arm32_push_r4_exact', '{r4}', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/arm32/mov.erobj', null, 1459, 'asm_arm32_mov_r4_r0_exact', 'r4, r0', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/arm32/mov.erobj', null, 1460, 'asm_arm32_mov_r1_r0_exact', 'r1, r0', 0),
  (3, 'mul', null, 'kernel/x86_64/object/instruction/arm32/mul.erobj', null, 1461, 'asm_arm32_mul_r0_r2_r3_exact', 'r0, r2, r3', 0);

insert or ignore into asm_dsl_rule(line_kind, op_name, operation_kind_id, instruction_path, form_path, encoding_id, rule_name, exact_operand_text, flags) values
  (3, 'ldr', null, 'kernel/x86_64/object/instruction/arm32/ldr.erobj', null, null, 'asm_arm32_ldr_known_gap', null, 2),
  (3, 'str', null, 'kernel/x86_64/object/instruction/arm32/str.erobj', null, null, 'asm_arm32_str_known_gap', null, 2),
  (3, 'bne', null, 'kernel/x86_64/object/instruction/arm32/bne.erobj', null, null, 'asm_arm32_bne_known_gap', null, 2),
  (3, 'beq', null, 'kernel/x86_64/object/instruction/arm32/beq.erobj', null, null, 'asm_arm32_beq_known_gap', null, 2),
  (3, 'bl', null, 'kernel/x86_64/object/instruction/arm32/bl.erobj', null, null, 'asm_arm32_bl_known_gap', null, 2),
  (3, 'movne', null, 'kernel/x86_64/object/instruction/arm32/movne.erobj', null, null, 'asm_arm32_movne_known_gap', null, 2),
  (3, 'moveq', null, 'kernel/x86_64/object/instruction/arm32/moveq.erobj', null, null, 'asm_arm32_moveq_known_gap', null, 2),
  (3, 'popne', null, 'kernel/x86_64/object/instruction/arm32/popne.erobj', null, null, 'asm_arm32_popne_known_gap', null, 2),
  (3, 'subs', null, 'kernel/x86_64/object/instruction/arm32/subs.erobj', null, null, 'asm_arm32_subs_known_gap', null, 2),
  (3, 'bxeq', null, 'kernel/x86_64/object/instruction/arm32/bxeq.erobj', null, null, 'asm_arm32_bxeq_known_gap', null, 2),
  (3, 'svc', null, 'kernel/x86_64/object/instruction/arm32/svc.erobj', null, null, 'asm_arm32_svc_known_gap', null, 2),
  (3, 'streq', null, 'kernel/x86_64/object/instruction/arm32/streq.erobj', null, null, 'asm_arm32_streq_known_gap', null, 2),
  (3, 'strne', null, 'kernel/x86_64/object/instruction/arm32/strne.erobj', null, null, 'asm_arm32_strne_known_gap', null, 2);

insert or ignore into asm_dsl_rule(line_kind, op_name, operation_kind_id, instruction_path, form_path, encoding_id, rule_name, exact_operand_text, flags) values
  (3, 'clc', null, 'kernel/x86_64/object/instruction/x86_64/clc.erobj', null, 1462, 'asm_x86_clc_exact', '', 0),
  (3, 'stc', null, 'kernel/x86_64/object/instruction/x86_64/stc.erobj', null, 1463, 'asm_x86_stc_exact', '', 0),
  (3, 'cdq', null, 'kernel/x86_64/object/instruction/x86_64/cdq.erobj', null, 1464, 'asm_x86_cdq_exact', '', 0),
  (3, 'rep', null, 'kernel/x86_64/object/instruction/x86_64/rep.erobj', null, 1465, 'asm_x86_rep_movsq_exact', 'movsq', 0),
  (3, 'rep', null, 'kernel/x86_64/object/instruction/x86_64/rep.erobj', null, 1466, 'asm_x86_rep_stosd_exact', 'stosd', 0),
  (3, 'setnz', null, 'kernel/x86_64/object/instruction/x86_64/setnz.erobj', null, 1467, 'asm_x86_setnz_al_exact', 'al', 0),
  (3, 'setnp', null, 'kernel/x86_64/object/instruction/x86_64/setnp.erobj', null, 1468, 'asm_x86_setnp_cl_exact', 'cl', 0),
  (3, 'ucomiss', null, 'kernel/x86_64/object/instruction/x86_64/ucomiss.erobj', null, 1469, 'asm_x86_ucomiss_xmm0_xmm1_exact', 'xmm0, xmm1', 0),
  (3, 'ucomiss', null, 'kernel/x86_64/object/instruction/x86_64/ucomiss.erobj', null, 1470, 'asm_x86_ucomiss_xmm0_xmm0_exact', 'xmm0, xmm0', 0),
  (3, 'ucomisd', null, 'kernel/x86_64/object/instruction/x86_64/ucomisd.erobj', null, 1471, 'asm_x86_ucomisd_xmm0_xmm1_exact', 'xmm0, xmm1', 0),
  (3, 'ucomisd', null, 'kernel/x86_64/object/instruction/x86_64/ucomisd.erobj', null, 1472, 'asm_x86_ucomisd_xmm0_xmm0_exact', 'xmm0, xmm0', 0),
  (3, 'movq', null, 'kernel/x86_64/object/instruction/x86_64/movq.erobj', null, 1473, 'asm_x86_movq_xmm0_rax_exact', 'xmm0, rax', 0),
  (3, 'movq', null, 'kernel/x86_64/object/instruction/x86_64/movq.erobj', null, 1474, 'asm_x86_movq_rax_xmm0_exact', 'rax, xmm0', 0),
  (3, 'movq', null, 'kernel/x86_64/object/instruction/x86_64/movq.erobj', null, 1475, 'asm_x86_movq_xmm1_rax_exact', 'xmm1, rax', 0),
  (3, 'xorps', null, 'kernel/x86_64/object/instruction/x86_64/xorps.erobj', null, 1476, 'asm_x86_xorps_xmm1_xmm1_exact', 'xmm1, xmm1', 0),
  (3, 'cvttss2si', null, 'kernel/x86_64/object/instruction/x86_64/cvttss2si.erobj', null, 1477, 'asm_x86_cvttss2si_eax_xmm0_exact', 'eax, xmm0', 0),
  (3, 'cvttss2si', null, 'kernel/x86_64/object/instruction/x86_64/cvttss2si.erobj', null, 1478, 'asm_x86_cvttss2si_rax_xmm0_exact', 'rax, xmm0', 0),
  (3, 'cvttsd2si', null, 'kernel/x86_64/object/instruction/x86_64/cvttsd2si.erobj', null, 1479, 'asm_x86_cvttsd2si_eax_xmm0_exact', 'eax, xmm0', 0),
  (3, 'cvttsd2si', null, 'kernel/x86_64/object/instruction/x86_64/cvttsd2si.erobj', null, 1480, 'asm_x86_cvttsd2si_rax_xmm0_exact', 'rax, xmm0', 0),
  (3, 'cvtsi2ss', null, 'kernel/x86_64/object/instruction/x86_64/cvtsi2ss.erobj', null, 1481, 'asm_x86_cvtsi2ss_xmm0_eax_exact', 'xmm0, eax', 0),
  (3, 'minss', null, 'kernel/x86_64/object/instruction/x86_64/minss.erobj', null, 1482, 'asm_x86_minss_xmm0_xmm1_exact', 'xmm0, xmm1', 0),
  (3, 'maxss', null, 'kernel/x86_64/object/instruction/x86_64/maxss.erobj', null, 1483, 'asm_x86_maxss_xmm0_xmm1_exact', 'xmm0, xmm1', 0),
  (3, 'movss', null, 'kernel/x86_64/object/instruction/x86_64/movss.erobj', null, 1484, 'asm_x86_movss_xmm0_rsp_ptr_exact', 'xmm0, [rsp]', 0);

insert or ignore into asm_dsl_rule(line_kind, op_name, operation_kind_id, instruction_path, form_path, encoding_id, rule_name, exact_operand_text, flags) values
  (3, 'rep', null, 'kernel/x86_64/object/instruction/x86_64/rep.erobj', null, 1485, 'asm_x86_rep_movsd_exact', 'movsd', 0),
  (3, 'repne', null, 'kernel/x86_64/object/instruction/x86_64/repne.erobj', null, 1486, 'asm_x86_repne_scasb_exact', 'scasb', 0),
  (3, 'setz', null, 'kernel/x86_64/object/instruction/x86_64/setz.erobj', null, 1487, 'asm_x86_setz_al_exact', 'al', 0),
  (3, 'rdtscp', null, 'kernel/x86_64/object/instruction/x86_64/rdtscp.erobj', null, 1488, 'asm_x86_rdtscp_exact', '', 0),
  (3, 'rol', null, 'kernel/x86_64/object/instruction/x86_64/rol.erobj', null, 1489, 'asm_x86_rol_ax_8_exact', 'ax, 8', 0),
  (3, 'cmovl', null, 'kernel/x86_64/object/instruction/x86_64/cmovl.erobj', null, 1490, 'asm_x86_cmovl_eax_edx_exact', 'eax, edx', 0);

insert or ignore into asm_dsl_rule(line_kind, op_name, operation_kind_id, instruction_path, form_path, encoding_id, rule_name, exact_operand_text, flags) values
  (3, 'lodsb', null, 'kernel/x86_64/object/instruction/x86_64/lodsb.erobj', null, 1491, 'asm_x86_lodsb_exact', '', 0),
  (3, 'cqo', null, 'kernel/x86_64/object/instruction/x86_64/cqo.erobj', null, 1492, 'asm_x86_cqo_exact', '', 0),
  (3, 'rol', null, 'kernel/x86_64/object/instruction/x86_64/rol.erobj', null, 1493, 'asm_x86_rol_cx_8_exact', 'cx, 8', 0),
  (3, 'lfence', null, 'kernel/x86_64/object/instruction/x86_64/lfence.erobj', null, 1494, 'asm_x86_lfence_exact', '', 0),
  (3, 'rdmsr', null, 'kernel/x86_64/object/instruction/x86_64/rdmsr.erobj', null, 1495, 'asm_x86_rdmsr_exact', '', 0),
  (3, 'wrmsr', null, 'kernel/x86_64/object/instruction/x86_64/wrmsr.erobj', null, 1496, 'asm_x86_wrmsr_exact', '', 0),
  (3, 'rol', null, 'kernel/x86_64/object/instruction/x86_64/rol.erobj', null, 1497, 'asm_x86_rol_eax_cl_exact', 'eax, cl', 0),
  (3, 'rol', null, 'kernel/x86_64/object/instruction/x86_64/rol.erobj', null, 1498, 'asm_x86_rol_rax_cl_exact', 'rax, cl', 0),
  (3, 'ror', null, 'kernel/x86_64/object/instruction/x86_64/ror.erobj', null, 1499, 'asm_x86_ror_eax_cl_exact', 'eax, cl', 0),
  (3, 'adc', null, 'kernel/x86_64/object/instruction/x86_64/adc.erobj', null, 1500, 'asm_x86_adc_ax_0_exact', 'ax, 0', 0),
  (3, 'cvtsi2sd', null, 'kernel/x86_64/object/instruction/x86_64/cvtsi2sd.erobj', null, 1501, 'asm_x86_cvtsi2sd_xmm0_eax_exact', 'xmm0, eax', 0),
  (3, 'cvtsi2sd', null, 'kernel/x86_64/object/instruction/x86_64/cvtsi2sd.erobj', null, 1502, 'asm_x86_cvtsi2sd_xmm0_rax_exact', 'xmm0, rax', 0),
  (3, 'cvtsi2ss', null, 'kernel/x86_64/object/instruction/x86_64/cvtsi2ss.erobj', null, 1503, 'asm_x86_cvtsi2ss_xmm0_rax_exact', 'xmm0, rax', 0),
  (3, 'cvtss2si', null, 'kernel/x86_64/object/instruction/x86_64/cvtss2si.erobj', null, 1504, 'asm_x86_cvtss2si_eax_xmm0_exact', 'eax, xmm0', 0),
  (3, 'pxor', null, 'kernel/x86_64/object/instruction/x86_64/pxor.erobj', null, 1505, 'asm_x86_pxor_xmm4_xmm4_exact', 'xmm4, xmm4', 0),
  (3, 'sqrtss', null, 'kernel/x86_64/object/instruction/x86_64/sqrtss.erobj', null, 1506, 'asm_x86_sqrtss_xmm0_xmm0_exact', 'xmm0, xmm0', 0),
  (3, 'xorps', null, 'kernel/x86_64/object/instruction/x86_64/xorps.erobj', null, 1507, 'asm_x86_xorps_xmm0_xmm0_exact', 'xmm0, xmm0', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1508, 'asm_x86_mov_esi_local_max_identities_exact', 'esi, LOCAL_MAX_IDENTITIES', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1509, 'asm_x86_mov_edx_seal_encoded_size_exact', 'edx, SEAL_ENCODED_SIZE', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1510, 'asm_x86_mov_edx_msg_test_len_exact', 'edx, msg_test_len', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1511, 'asm_x86_mov_ecx_msg_blind_len_exact', 'ecx, msg_blind_len', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1512, 'asm_x86_mov_edx_raw_size_exact', 'edx, RAW_SIZE', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1513, 'asm_x86_mov_esi_stamp_size_exact', 'esi, STAMP_SIZE', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1514, 'asm_x86_mov_esi_domain_len_exact', 'esi, DOMAIN_LEN', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1515, 'asm_x86_mov_ecx_value_len_exact', 'ecx, VALUE_LEN', 0),
  (3, 'imul', null, 'kernel/x86_64/object/instruction/x86_64/imul.erobj', null, 1516, 'asm_x86_imul_eax_eax_31_exact', 'eax, eax, 31', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1517, 'asm_x86_add_eax_7_exact', 'eax, 7', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1518, 'asm_x86_cmp_ecx_data_size_exact', 'ecx, DATA_SIZE', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1519, 'asm_x86_mov_esi_data_size_exact', 'esi, DATA_SIZE', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1520, 'asm_x86_mov_rsi_rbx_host_import_name_ptr_exact', 'rsi, [rbx + HOST_IMPORT_NAME_PTR_OFF]', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1521, 'asm_x86_add_rbx_host_import_size_exact', 'rbx, HOST_IMPORT_SIZE', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1522, 'asm_x86_mov_dl_agent_flag_sync_exact', 'dl, AGENT_FLAG_SYNC', 0),
  (3, 'imul', null, 'kernel/x86_64/object/instruction/x86_64/imul.erobj', null, 1523, 'asm_x86_imul_rax_host_import_size_exact', 'rax, HOST_IMPORT_SIZE', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1524, 'asm_x86_mov_r15_rax_host_import_fn_ptr_exact', 'r15, [rax + HOST_IMPORT_FN_PTR_OFF]', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1525, 'asm_x86_mov_rdi_rax_host_import_module_ptr_exact', 'rdi, [rax + HOST_IMPORT_MODULE_PTR_OFF]', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1526, 'asm_x86_mov_rdi_rax_host_import_name_ptr_exact', 'rdi, [rax + HOST_IMPORT_NAME_PTR_OFF]', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1527, 'asm_x86_mov_rsi_rax_host_import_module_len_exact', 'rsi, [rax + HOST_IMPORT_MODULE_LEN_OFF]', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1528, 'asm_x86_mov_rsi_rax_host_import_name_len_exact', 'rsi, [rax + HOST_IMPORT_NAME_LEN_OFF]', 0),
  (3, 'test', null, 'kernel/x86_64/object/instruction/x86_64/test.erobj', null, 1529, 'asm_x86_test_bl_agent_flag_sync_exact', 'bl, AGENT_FLAG_SYNC', 0),
  (3, 'test', null, 'kernel/x86_64/object/instruction/x86_64/test.erobj', null, 1530, 'asm_x86_test_cl_agent_flag_sync_exact', 'cl, AGENT_FLAG_SYNC', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1531, 'asm_x86_mov_rsi_bytes_pattern64_exact', 'rsi, 0x1122334455667788', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1532, 'asm_x86_mov_rbx_bytes_pattern64_exact', 'rbx, 0x1122334455667788', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1533, 'asm_x86_cmp_rax_rbx_exact', 'rax, rbx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1534, 'asm_x86_mov_esi_bytes_pattern32_exact', 'esi, 0x11223344', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1535, 'asm_x86_mov_esi_aabb_exact', 'esi, 0xaabb', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1536, 'asm_x86_mov_r15d_r9d_exact', 'r15d, r9d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1537, 'asm_x86_mov_rsp16_rax_exact', '[rsp + 16], rax', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1538, 'asm_x86_cmp_r10d_eax_exact', 'r10d, eax', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1539, 'asm_x86_add_eax_4_exact', 'eax, 4', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1540, 'asm_x86_mov_rcx_rsp_exact', 'rcx, rsp', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1541, 'asm_x86_add_rsp_40_exact', 'rsp, 40', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1542, 'asm_x86_mov_esi_rsp_ptr_exact', 'esi, [rsp]', 0),
  (3, 'imul', null, 'kernel/x86_64/object/instruction/x86_64/imul.erobj', null, 1543, 'asm_x86_imul_eax_r14d_exact', 'eax, r14d', 0),
  (3, 'imul', null, 'kernel/x86_64/object/instruction/x86_64/imul.erobj', null, 1544, 'asm_x86_imul_eax_ecx_exact', 'eax, ecx', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1545, 'asm_x86_add_rsp_56_exact', 'rsp, 56', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1546, 'asm_x86_mov_r8d_r15d_exact', 'r8d, r15d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1547, 'asm_x86_mov_rsp_ptr_ecx_exact', '[rsp], ecx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1548, 'asm_x86_mov_ecx_r11d_exact', 'ecx, r11d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1549, 'asm_x86_mov_ecx_r12d_exact', 'ecx, r12d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1550, 'asm_x86_mov_esi_rsp8_ptr_exact', 'esi, [rsp + 8]', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1551, 'asm_x86_cmp_eax_255_exact', 'eax, 255', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1552, 'asm_x86_cmp_ecx_4_exact', 'ecx, 4', 0),
  (3, 'shl', null, 'kernel/x86_64/object/instruction/x86_64/shl.erobj', null, 1553, 'asm_x86_shl_eax_4_exact', 'eax, 4', 0),
  (3, 'shr', null, 'kernel/x86_64/object/instruction/x86_64/shr.erobj', null, 1554, 'asm_x86_shr_ecx_1_exact', 'ecx, 1', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1555, 'asm_x86_mov_ecx_r13d_exact', 'ecx, r13d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1556, 'asm_x86_mov_rsp32_rax_exact', '[rsp + 32], rax', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1557, 'asm_x86_mov_rsp40_rax_exact', '[rsp + 40], rax', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1558, 'asm_x86_cmp_ebx_eax_exact', 'ebx, eax', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1559, 'asm_x86_mov_r8d_ebx_exact', 'r8d, ebx', 0),
  (3, 'shl', null, 'kernel/x86_64/object/instruction/x86_64/shl.erobj', null, 1560, 'asm_x86_shl_ecx_6_exact', 'ecx, 6', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1561, 'asm_x86_add_eax_esi_exact', 'eax, esi', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1562, 'asm_x86_cmp_ecx_ebx_exact', 'ecx, ebx', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1563, 'asm_x86_cmp_eax_5_exact', 'eax, 5', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1564, 'asm_x86_mov_rdi_rcx_ptr_al_exact', '[rdi + rcx], al', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1565, 'asm_x86_cmp_ecx_eax_exact', 'ecx, eax', 0),
  (3, 'shl', null, 'kernel/x86_64/object/instruction/x86_64/shl.erobj', null, 1566, 'asm_x86_shl_edx_16_exact', 'edx, 16', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1567, 'asm_x86_mov_esi_ecx_exact', 'esi, ecx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1568, 'asm_x86_mov_rdi_rsp_ptr_exact', 'rdi, [rsp]', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1569, 'asm_x86_mov_r8_r14_exact', 'r8, r14', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1570, 'asm_x86_mov_r8d_r10d_exact', 'r8d, r10d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1571, 'asm_x86_mov_rsi_rcx_exact', 'rsi, rcx', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1572, 'asm_x86_cmp_ecx_r14d_exact', 'ecx, r14d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1573, 'asm_x86_mov_eax_rsp4_ptr_exact', 'eax, [rsp + 4]', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1574, 'asm_x86_mov_rsi_rsp_ptr_exact', 'rsi, [rsp]', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1575, 'asm_x86_mov_eax_rsp24_ptr_exact', 'eax, [rsp + 24]', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1576, 'asm_x86_mov_rcx_rsp16_ptr_exact', 'rcx, [rsp + 16]', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1577, 'asm_x86_mov_r9_rbx_exact', 'r9, rbx', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1578, 'asm_x86_cmp_r9d_r14d_exact', 'r9d, r14d', 0),
  (3, 'shl', null, 'kernel/x86_64/object/instruction/x86_64/shl.erobj', null, 1579, 'asm_x86_shl_ecx_8_exact', 'ecx, 8', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1580, 'asm_x86_mov_dword_rsp_ptr_0_exact', 'dword [rsp], 0', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1581, 'asm_x86_mov_ebx_2_exact', 'ebx, 2', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1582, 'asm_x86_mov_eax_3_exact', 'eax, 3', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1583, 'asm_x86_add_ecx_edx_exact', 'ecx, edx', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1584, 'asm_x86_mov_rdi_rsp8_ptr_exact', 'rdi, [rsp + 8]', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1585, 'asm_x86_mov_edx_rsp4_ptr_exact', 'edx, [rsp + 4]', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1586, 'asm_x86_mov_rsp8_eax_exact', '[rsp + 8], eax', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1587, 'asm_x86_mov_rsp_rcx_dl_exact', '[rsp + rcx], dl', 0),
  (3, 'shl', null, 'kernel/x86_64/object/instruction/x86_64/shl.erobj', null, 1588, 'asm_x86_shl_edx_8_exact', 'edx, 8', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1589, 'asm_x86_mov_ecx_r9d_exact', 'ecx, r9d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1590, 'asm_x86_mov_ecx_edx_exact', 'ecx, edx', 0),
  (3, 'cmp', null, 'kernel/x86_64/object/instruction/x86_64/cmp.erobj', null, 1591, 'asm_x86_cmp_esi_3_exact', 'esi, 3', 0),
  (3, 'imul', null, 'kernel/x86_64/object/instruction/x86_64/imul.erobj', null, 1592, 'asm_x86_imul_eax_r8d_exact', 'eax, r8d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1593, 'asm_x86_mov_rsp_ptr_r9_exact', '[rsp], r9', 0),
  (3, 'test', null, 'kernel/x86_64/object/instruction/x86_64/test.erobj', null, 1594, 'asm_x86_test_edi_edi_exact', 'edi, edi', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1595, 'asm_x86_add_ecx_eax_exact', 'ecx, eax', 0),
  (3, 'imul', null, 'kernel/x86_64/object/instruction/x86_64/imul.erobj', null, 1596, 'asm_x86_imul_eax_r13d_exact', 'eax, r13d', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1597, 'asm_x86_mov_dword_rsp4_ptr_0_exact', 'dword [rsp + 4], 0', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1598, 'asm_x86_mov_r13_r8_exact', 'r13, r8', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1599, 'asm_x86_mov_rdi1_ptr_al_exact', '[rdi + 1], al', 0),
  (3, 'add', null, 'kernel/x86_64/object/instruction/x86_64/add.erobj', null, 1600, 'asm_x86_add_r11d_eax_exact', 'r11d, eax', 0),
  (3, 'mov', null, 'kernel/x86_64/object/instruction/x86_64/mov.erobj', null, 1601, 'asm_x86_mov_r10_rsp8_ptr_exact', 'r10, [rsp + 8]', 0),
  (3, 'lea', null, 'kernel/x86_64/object/instruction/x86_64/lea.erobj', null, 1602, 'asm_x86_lea_rdx_rsp_ptr_exact', 'rdx, [rsp]', 0),
  (3, 'lea', null, 'kernel/x86_64/object/instruction/x86_64/lea.erobj', null, 1603, 'asm_x86_lea_rdi_r13_rax_ptr_exact', 'rdi, [r13 + rax]', 0);

insert or ignore into asm_dsl_rule(line_kind, op_name, operation_kind_id, instruction_path, form_path, encoding_id, rule_name, exact_operand_text, flags) values
  (3, 'b', null, 'kernel/x86_64/object/instruction/arm32/b.erobj', null, null, 'asm_arm32_b_known_gap', null, 2),
  (3, 'blo', null, 'kernel/x86_64/object/instruction/arm32/blo.erobj', null, null, 'asm_arm32_blo_known_gap', null, 2),
  (3, 'bhi', null, 'kernel/x86_64/object/instruction/arm32/bhi.erobj', null, null, 'asm_arm32_bhi_known_gap', null, 2),
  (3, 'orr', null, 'kernel/x86_64/object/instruction/arm32/orr.erobj', null, null, 'asm_arm32_orr_known_gap', null, 2),
  (3, 'ldrb', null, 'kernel/x86_64/object/instruction/arm32/ldrb.erobj', null, null, 'asm_arm32_ldrb_known_gap', null, 2),
  (3, 'lsl', null, 'kernel/x86_64/object/instruction/arm32/lsl.erobj', null, null, 'asm_arm32_lsl_known_gap', null, 2),
  (3, 'lsr', null, 'kernel/x86_64/object/instruction/arm32/lsr.erobj', null, null, 'asm_arm32_lsr_known_gap', null, 2),
  (3, 'strb', null, 'kernel/x86_64/object/instruction/arm32/strb.erobj', null, null, 'asm_arm32_strb_known_gap', null, 2),
  (3, 'strh', null, 'kernel/x86_64/object/instruction/arm32/strh.erobj', null, null, 'asm_arm32_strh_known_gap', null, 2),
  (3, 'tst', null, 'kernel/x86_64/object/instruction/arm32/tst.erobj', null, null, 'asm_arm32_tst_known_gap', null, 2),
  (3, 'popeq', null, 'kernel/x86_64/object/instruction/arm32/popeq.erobj', null, null, 'asm_arm32_popeq_known_gap', null, 2),
  (3, 'bic', null, 'kernel/x86_64/object/instruction/arm32/bic.erobj', null, null, 'asm_arm32_bic_known_gap', null, 2),
  (3, 'bxne', null, 'kernel/x86_64/object/instruction/arm32/bxne.erobj', null, null, 'asm_arm32_bxne_known_gap', null, 2),
  (3, 'mvn', null, 'kernel/x86_64/object/instruction/arm32/mvn.erobj', null, null, 'asm_arm32_mvn_known_gap', null, 2),
  (3, 'ldreq', null, 'kernel/x86_64/object/instruction/arm32/ldreq.erobj', null, null, 'asm_arm32_ldreq_known_gap', null, 2),
  (3, 'bhs', null, 'kernel/x86_64/object/instruction/arm32/bhs.erobj', null, null, 'asm_arm32_bhs_known_gap', null, 2),
  (3, 'ldrh', null, 'kernel/x86_64/object/instruction/arm32/ldrh.erobj', null, null, 'asm_arm32_ldrh_known_gap', null, 2),
  (3, 'jp', null, 'kernel/x86_64/object/instruction/x86_64/jp.erobj', null, null, 'asm_x86_jp_known_gap', null, 2),
  (3, 'loop', null, 'kernel/x86_64/object/instruction/x86_64/loop.erobj', null, null, 'asm_x86_loop_known_gap', null, 2),
  (3, 'lgdt', null, 'kernel/x86_64/object/instruction/x86_64/lgdt.erobj', null, null, 'asm_x86_lgdt_known_gap', null, 2),
  (3, 'ror', null, 'kernel/x86_64/object/instruction/x86_64/ror.erobj', null, null, 'asm_x86_ror_known_gap', null, 2),
  (3, 'rol', null, 'kernel/x86_64/object/instruction/x86_64/rol.erobj', null, null, 'asm_x86_rol_known_gap', null, 2),
  (3, 'adc', null, 'kernel/x86_64/object/instruction/x86_64/adc.erobj', null, null, 'asm_x86_adc_known_gap', null, 2),
  (3, 'cmova', null, 'kernel/x86_64/object/instruction/x86_64/cmova.erobj', null, null, 'asm_x86_cmova_known_gap', null, 2),
  (3, 'cmovl', null, 'kernel/x86_64/object/instruction/x86_64/cmovl.erobj', null, null, 'asm_x86_cmovl_known_gap', null, 2),
  (3, 'cmovz', null, 'kernel/x86_64/object/instruction/x86_64/cmovz.erobj', null, null, 'asm_x86_cmovz_known_gap', null, 2),
  (3, 'cmovb', null, 'kernel/x86_64/object/instruction/x86_64/cmovb.erobj', null, null, 'asm_x86_cmovb_known_gap', null, 2),
  (3, 'cmovg', null, 'kernel/x86_64/object/instruction/x86_64/cmovg.erobj', null, null, 'asm_x86_cmovg_known_gap', null, 2),
  (3, 'crc32', null, 'kernel/x86_64/object/instruction/x86_64/crc32.erobj', null, null, 'asm_x86_crc32_known_gap', null, 2),
  (3, 'movq', null, 'kernel/x86_64/object/instruction/x86_64/movq.erobj', null, null, 'asm_x86_movq_known_gap', null, 2),
  (3, 'movd', null, 'kernel/x86_64/object/instruction/x86_64/movd.erobj', null, null, 'asm_x86_movd_known_gap', null, 2),
  (3, 'subsd', null, 'kernel/x86_64/object/instruction/x86_64/subsd.erobj', null, null, 'asm_x86_subsd_known_gap', null, 2),
  (3, 'roundsd', null, 'kernel/x86_64/object/instruction/x86_64/roundsd.erobj', null, null, 'asm_x86_roundsd_known_gap', null, 2),
  (3, 'roundss', null, 'kernel/x86_64/object/instruction/x86_64/roundss.erobj', null, null, 'asm_x86_roundss_known_gap', null, 2),
  (3, 'repe', null, 'kernel/x86_64/object/instruction/x86_64/repe.erobj', null, null, 'asm_x86_repe_known_gap', null, 2),
  (3, 'movss', null, 'kernel/x86_64/object/instruction/x86_64/movss.erobj', null, null, 'asm_x86_movss_known_gap', null, 2),
  (3, 'ucomiss', null, 'kernel/x86_64/object/instruction/x86_64/ucomiss.erobj', null, null, 'asm_x86_ucomiss_known_gap', null, 2),
  (3, 'addss', null, 'kernel/x86_64/object/instruction/x86_64/addss.erobj', null, null, 'asm_x86_addss_known_gap', null, 2),
  (3, 'divss', null, 'kernel/x86_64/object/instruction/x86_64/divss.erobj', null, null, 'asm_x86_divss_known_gap', null, 2),
  (3, 'mulss', null, 'kernel/x86_64/object/instruction/x86_64/mulss.erobj', null, null, 'asm_x86_mulss_known_gap', null, 2),
  (3, 'subss', null, 'kernel/x86_64/object/instruction/x86_64/subss.erobj', null, null, 'asm_x86_subss_known_gap', null, 2),
  (3, 'movsxd', null, 'kernel/x86_64/object/instruction/x86_64/movsxd.erobj', null, null, 'asm_x86_movsxd_known_gap', null, 2),
  (3, 'setb', null, 'kernel/x86_64/object/instruction/x86_64/setb.erobj', null, null, 'asm_x86_setb_known_gap', null, 2),
  (3, 'setbe', null, 'kernel/x86_64/object/instruction/x86_64/setbe.erobj', null, null, 'asm_x86_setbe_known_gap', null, 2);

create table asm_exact_fixed_encoding_fact (
  encoding_id integer primary key,
  isa_id integer not null default 1 references isa(isa_id),
  name text not null unique,
  rule_name text not null unique,
  op_name text not null,
  operand_text text not null,
  fixed_hex text not null
);

insert into asm_exact_fixed_encoding_fact(encoding_id, name, rule_name, op_name, operand_text, fixed_hex) values
  (1604, 'x86_64_vp8_cmp_ecx_vp8_block_size', 'asm_x86_vp8_cmp_ecx_vp8_block_size_exact', 'cmp', 'ecx, VP8_BLOCK_SIZE', '83f904'),
  (1605, 'x86_64_vp8_mov_edx_vp8_chroma_block_size', 'asm_x86_vp8_mov_edx_vp8_chroma_block_size_exact', 'mov', 'edx, VP8_CHROMA_BLOCK_SIZE', 'ba08000000'),
  (1606, 'x86_64_vp8_mov_edx_vp8_macroblock_size', 'asm_x86_vp8_mov_edx_vp8_macroblock_size_exact', 'mov', 'edx, VP8_MACROBLOCK_SIZE', 'ba10000000'),
  (1607, 'x86_64_vp8_cmp_eax_vp8_macroblock_size', 'asm_x86_vp8_cmp_eax_vp8_macroblock_size_exact', 'cmp', 'eax, VP8_MACROBLOCK_SIZE', '83f810'),
  (1608, 'x86_64_vp8_cmp_r8d_vp8_macroblock_size', 'asm_x86_vp8_cmp_r8d_vp8_macroblock_size_exact', 'cmp', 'r8d, VP8_MACROBLOCK_SIZE', '4183f810'),
  (1609, 'x86_64_vp8_mov_edx_vp8_block_size', 'asm_x86_vp8_mov_edx_vp8_block_size_exact', 'mov', 'edx, VP8_BLOCK_SIZE', 'ba04000000'),
  (1610, 'x86_64_vp8_mov_esi_vp8_intra4_mode_dc', 'asm_x86_vp8_mov_esi_vp8_intra4_mode_dc_exact', 'mov', 'esi, VP8_INTRA4_MODE_DC', 'be00000000'),
  (1611, 'x86_64_vp8_mov_esi_vp8_idct_sinpi8sqrt2', 'asm_x86_vp8_mov_esi_vp8_idct_sinpi8sqrt2_exact', 'mov', 'esi, VP8_IDCT_SINPI8SQRT2', 'be8c8a0000'),
  (1612, 'x86_64_vp8_cmp_ecx_vp8_y_block_count', 'asm_x86_vp8_cmp_ecx_vp8_y_block_count_exact', 'cmp', 'ecx, VP8_Y_BLOCK_COUNT', '83f910'),
  (1613, 'x86_64_vp8_mov_edx_vp8_block_size_times_vp8_motion_vector_size', 'asm_x86_vp8_mov_edx_vp8_block_size_times_vp8_motion_vector_size_exact', 'mov', 'edx, VP8_BLOCK_SIZE * VP8_MOTION_VECTOR_SIZE', 'ba10000000'),
  (1614, 'x86_64_vp8_cmp_ecx_vp8_macroblock_size', 'asm_x86_vp8_cmp_ecx_vp8_macroblock_size_exact', 'cmp', 'ecx, VP8_MACROBLOCK_SIZE', '83f910'),
  (1615, 'x86_64_vp8_mov_edx_vp8_frame_type_key', 'asm_x86_vp8_mov_edx_vp8_frame_type_key_exact', 'mov', 'edx, VP8_FRAME_TYPE_KEY', 'ba00000000'),
  (1616, 'x86_64_vp8_mov_edx_vp8_max_luma_token_columns', 'asm_x86_vp8_mov_edx_vp8_max_luma_token_columns_exact', 'mov', 'edx, VP8_MAX_LUMA_TOKEN_COLUMNS', 'ba00100000'),
  (1617, 'x86_64_vp8_mov_edx_vp8_residual_context_size', 'asm_x86_vp8_mov_edx_vp8_residual_context_size_exact', 'mov', 'edx, VP8_RESIDUAL_CONTEXT_SIZE', 'ba09240000'),
  (1618, 'x86_64_vp8_cmp_eax_vp8_quant_index_max', 'asm_x86_vp8_cmp_eax_vp8_quant_index_max_exact', 'cmp', 'eax, VP8_QUANT_INDEX_MAX', '83f87f'),
  (1619, 'x86_64_vp8_mov_edx_vp8_frame_type_inter', 'asm_x86_vp8_mov_edx_vp8_frame_type_inter_exact', 'mov', 'edx, VP8_FRAME_TYPE_INTER', 'ba01000000'),
  (1620, 'x86_64_vp8_cmp_eax_vp8_intra4_mode_horizontal_up', 'asm_x86_vp8_cmp_eax_vp8_intra4_mode_horizontal_up_exact', 'cmp', 'eax, VP8_INTRA4_MODE_HORIZONTAL_UP', '83f809'),
  (1621, 'x86_64_vp8_cmp_eax_vp8_luma_mode_b_pred', 'asm_x86_vp8_cmp_eax_vp8_luma_mode_b_pred_exact', 'cmp', 'eax, VP8_LUMA_MODE_B_PRED', '83f804'),
  (1622, 'x86_64_vp8_mov_esi_vp8_chroma_block_size', 'asm_x86_vp8_mov_esi_vp8_chroma_block_size_exact', 'mov', 'esi, VP8_CHROMA_BLOCK_SIZE', 'be08000000'),
  (1623, 'x86_64_vp8_mov_esi_vp8_macroblock_size', 'asm_x86_vp8_mov_esi_vp8_macroblock_size_exact', 'mov', 'esi, VP8_MACROBLOCK_SIZE', 'be10000000'),
  (1624, 'x86_64_vp8_mov_esi_vp8_quant_delta_bits', 'asm_x86_vp8_mov_esi_vp8_quant_delta_bits_exact', 'mov', 'esi, VP8_QUANT_DELTA_BITS', 'be04000000'),
  (1625, 'x86_64_vp8_movzx_eax_byte_ptr_rsp_plus_72_plus_vp8_loop_filter_param_hev_threshold', 'asm_x86_vp8_movzx_eax_byte_ptr_rsp_plus_72_plus_vp8_loop_filter_param_hev_threshold_exact', 'movzx', 'eax, byte [rsp + 72 + VP8_LOOP_FILTER_PARAM_HEV_THRESHOLD]', '0fb644244a'),
  (1626, 'x86_64_vp8_movzx_eax_byte_ptr_rsp_plus_80_plus_vp8_loop_filter_param_interior_limit', 'asm_x86_vp8_movzx_eax_byte_ptr_rsp_plus_80_plus_vp8_loop_filter_param_interior_limit_exact', 'movzx', 'eax, byte [rsp + 80 + VP8_LOOP_FILTER_PARAM_INTERIOR_LIMIT]', '0fb6442451'),
  (1627, 'x86_64_vp8_mov_ecx_ptr_rsp_plus_vp8_decode_stack_mb_y', 'asm_x86_vp8_mov_ecx_ptr_rsp_plus_vp8_decode_stack_mb_y_exact', 'mov', 'ecx, [rsp + VP8_DECODE_STACK_MB_Y]', '8b8c24c50b0000'),
  (1628, 'x86_64_vp8_mov_edx_ptr_rsp_plus_vp8_decode_stack_mb_x', 'asm_x86_vp8_mov_edx_ptr_rsp_plus_vp8_decode_stack_mb_x_exact', 'mov', 'edx, [rsp + VP8_DECODE_STACK_MB_X]', '8b9424c10b0000'),
  (1629, 'x86_64_vp8_mov_edi_ptr_rsp_plus_vp8_decode_stack_width', 'asm_x86_vp8_mov_edi_ptr_rsp_plus_vp8_decode_stack_width_exact', 'mov', 'edi, [rsp + VP8_DECODE_STACK_WIDTH]', '8bbc24690b0000'),
  (1630, 'x86_64_vp8_cmp_eax_vp8_subpixel_filter_phase_count', 'asm_x86_vp8_cmp_eax_vp8_subpixel_filter_phase_count_exact', 'cmp', 'eax, VP8_SUBPIXEL_FILTER_PHASE_COUNT', '83f808'),
  (1631, 'x86_64_vp8_cmp_r8d_vp8_block_size', 'asm_x86_vp8_cmp_r8d_vp8_block_size_exact', 'cmp', 'r8d, VP8_BLOCK_SIZE', '4183f804'),
  (1632, 'x86_64_vp8_lea_rax_ptr_rsp_plus_8_plus_vp8_decode_stack_u_plane', 'asm_x86_vp8_lea_rax_ptr_rsp_plus_8_plus_vp8_decode_stack_u_plane_exact', 'lea', 'rax, [rsp + 8 + VP8_DECODE_STACK_U_PLANE]', '488d8424f10a0000'),
  (1633, 'x86_64_vp8_lea_rax_ptr_rsp_plus_vp8_decode_stack_v_plane', 'asm_x86_vp8_lea_rax_ptr_rsp_plus_vp8_decode_stack_v_plane_exact', 'lea', 'rax, [rsp + VP8_DECODE_STACK_V_PLANE]', '488d8424290b0000'),
  (1634, 'x86_64_vp8_mov_eax_vp8_coeff_block_coeff_count', 'asm_x86_vp8_mov_eax_vp8_coeff_block_coeff_count_exact', 'mov', 'eax, VP8_COEFF_BLOCK_COEFF_COUNT', 'b810000000'),
  (1635, 'x86_64_vp8_cmp_ebx_vp8_block_size', 'asm_x86_vp8_cmp_ebx_vp8_block_size_exact', 'cmp', 'ebx, VP8_BLOCK_SIZE', '83fb04'),
  (1636, 'x86_64_vp8_mov_eax_ptr_rsp_plus_vp8_decode_stack_chroma_count', 'asm_x86_vp8_mov_eax_ptr_rsp_plus_vp8_decode_stack_chroma_count_exact', 'mov', 'eax, [rsp + VP8_DECODE_STACK_CHROMA_COUNT]', '8b8424cd0b0000'),
  (1637, 'x86_64_vp8_mov_eax_ptr_rsp_plus_vp8_decode_stack_pixel_count', 'asm_x86_vp8_mov_eax_ptr_rsp_plus_vp8_decode_stack_pixel_count_exact', 'mov', 'eax, [rsp + VP8_DECODE_STACK_PIXEL_COUNT]', '8b8424c90b0000'),
  (1638, 'x86_64_vp8_cmp_ebx_vp8_uv_block_count', 'asm_x86_vp8_cmp_ebx_vp8_uv_block_count_exact', 'cmp', 'ebx, VP8_UV_BLOCK_COUNT', '83fb04'),
  (1639, 'x86_64_vp8_cmp_ebx_vp8_y_block_count', 'asm_x86_vp8_cmp_ebx_vp8_y_block_count_exact', 'cmp', 'ebx, VP8_Y_BLOCK_COUNT', '83fb10'),
  (1640, 'x86_64_vp8_imul_r9_vp8_coeff_block_bytes', 'asm_x86_vp8_imul_r9_vp8_coeff_block_bytes_exact', 'imul', 'r9, VP8_COEFF_BLOCK_BYTES', '4d6bc920'),
  (1641, 'x86_64_vp8_lea_rdi_ptr_rsp_plus_vp8_decode_stack_dequant', 'asm_x86_vp8_lea_rdi_ptr_rsp_plus_vp8_decode_stack_dequant_exact', 'lea', 'rdi, [rsp + VP8_DECODE_STACK_DEQUANT]', '488dbc2481090000'),
  (1642, 'x86_64_vp8_mov_eax_vp8_motion_vector_size', 'asm_x86_vp8_mov_eax_vp8_motion_vector_size_exact', 'mov', 'eax, VP8_MOTION_VECTOR_SIZE', 'b804000000'),
  (1643, 'x86_64_vp8_mov_eax_vp8_y_block_count', 'asm_x86_vp8_mov_eax_vp8_y_block_count_exact', 'mov', 'eax, VP8_Y_BLOCK_COUNT', 'b810000000'),
  (1644, 'x86_64_vp8_mov_ecx_ptr_rsp_plus_vp8_decode_stack_mb_x', 'asm_x86_vp8_mov_ecx_ptr_rsp_plus_vp8_decode_stack_mb_x_exact', 'mov', 'ecx, [rsp + VP8_DECODE_STACK_MB_X]', '8b8c24c10b0000'),
  (1645, 'x86_64_vp8_mov_esi_vp8_plane_edge_default', 'asm_x86_vp8_mov_esi_vp8_plane_edge_default_exact', 'mov', 'esi, VP8_PLANE_EDGE_DEFAULT', 'be7f000000'),
  (1646, 'x86_64_vp8_mov_esi_vp8_plane_left_default', 'asm_x86_vp8_mov_esi_vp8_plane_left_default_exact', 'mov', 'esi, VP8_PLANE_LEFT_DEFAULT', 'be81000000'),
  (1647, 'x86_64_vp8_mov_r8d_ptr_rsp_plus_vp8_decode_stack_mb_y', 'asm_x86_vp8_mov_r8d_ptr_rsp_plus_vp8_decode_stack_mb_y_exact', 'mov', 'r8d, [rsp + VP8_DECODE_STACK_MB_Y]', '448b8424c50b0000'),
  (1648, 'x86_64_vp8_movzx_r9d_byte_ptr_rsp_plus_64_plus_vp8_loop_filter_param_edge_limit', 'asm_x86_vp8_movzx_r9d_byte_ptr_rsp_plus_64_plus_vp8_loop_filter_param_edge_limit_exact', 'movzx', 'r9d, byte [rsp + 64 + VP8_LOOP_FILTER_PARAM_EDGE_LIMIT]', '440fb64c2440'),
  (1649, 'x86_64_vp8_imul_eax_vp8_motion_vector_size', 'asm_x86_vp8_imul_eax_vp8_motion_vector_size_exact', 'imul', 'eax, VP8_MOTION_VECTOR_SIZE', '6bc004'),
  (1650, 'x86_64_vp8_mov_edi_ptr_rsp_plus_vp8_decode_stack_chroma_width', 'asm_x86_vp8_mov_edi_ptr_rsp_plus_vp8_decode_stack_chroma_width_exact', 'mov', 'edi, [rsp + VP8_DECODE_STACK_CHROMA_WIDTH]', '8bbc24710b0000'),
  (1651, 'x86_64_vp8_mov_esi_vp8_inter_reference_probability_bits', 'asm_x86_vp8_mov_esi_vp8_inter_reference_probability_bits_exact', 'mov', 'esi, VP8_INTER_REFERENCE_PROBABILITY_BITS', 'be08000000'),
  (1652, 'x86_64_vp8_mov_esi_ptr_rsp_plus_vp8_decode_stack_chroma_height', 'asm_x86_vp8_mov_esi_ptr_rsp_plus_vp8_decode_stack_chroma_height_exact', 'mov', 'esi, [rsp + VP8_DECODE_STACK_CHROMA_HEIGHT]', '8bb424750b0000'),
  (1653, 'x86_64_vp8_mov_esi_ptr_rsp_plus_vp8_decode_stack_height', 'asm_x86_vp8_mov_esi_ptr_rsp_plus_vp8_decode_stack_height_exact', 'mov', 'esi, [rsp + VP8_DECODE_STACK_HEIGHT]', '8bb4246d0b0000'),
  (1654, 'x86_64_vp8_mov_esi_ptr_rsp_plus_vp8_decode_stack_mb_x', 'asm_x86_vp8_mov_esi_ptr_rsp_plus_vp8_decode_stack_mb_x_exact', 'mov', 'esi, [rsp + VP8_DECODE_STACK_MB_X]', '8bb424c10b0000'),
  (1655, 'x86_64_vp8_add_eax_vp8_idct_round', 'asm_x86_vp8_add_eax_vp8_idct_round_exact', 'add', 'eax, VP8_IDCT_ROUND', '83c004'),
  (1656, 'x86_64_vp8_add_eax_vp8_wht_round', 'asm_x86_vp8_add_eax_vp8_wht_round_exact', 'add', 'eax, VP8_WHT_ROUND', '83c003'),
  (1657, 'x86_64_vp8_cmp_byte_ptr_rsp_plus_vp8_decode_stack_mb_header_plus_vp8_macroblock_header_skip_0', 'asm_x86_vp8_cmp_byte_ptr_rsp_plus_vp8_decode_stack_mb_header_plus_vp8_macroblock_header_skip_0_exact', 'cmp', 'byte [rsp + VP8_DECODE_STACK_MB_HEADER + VP8_MACROBLOCK_HEADER_SKIP], 0', '80bc240806000000'),
  (1658, 'x86_64_vp8_cmp_ebx_vp8_loop_filter_delta_count', 'asm_x86_vp8_cmp_ebx_vp8_loop_filter_delta_count_exact', 'cmp', 'ebx, VP8_LOOP_FILTER_DELTA_COUNT', '83fb04'),
  (1659, 'x86_64_vp8_cmp_ebx_vp8_segment_count', 'asm_x86_vp8_cmp_ebx_vp8_segment_count_exact', 'cmp', 'ebx, VP8_SEGMENT_COUNT', '83fb04'),
  (1660, 'x86_64_vp8_cmp_ecx_vp8_coeff_block_coeff_count', 'asm_x86_vp8_cmp_ecx_vp8_coeff_block_coeff_count_exact', 'cmp', 'ecx, VP8_COEFF_BLOCK_COEFF_COUNT', '83f910'),
  (1661, 'x86_64_vp8_cmp_ecx_vp8_subpixel_filter_tap_count', 'asm_x86_vp8_cmp_ecx_vp8_subpixel_filter_tap_count_exact', 'cmp', 'ecx, VP8_SUBPIXEL_FILTER_TAP_COUNT', '83f906'),
  (1662, 'x86_64_vp8_cmp_edi_vp8_quant_index_max', 'asm_x86_vp8_cmp_edi_vp8_quant_index_max_exact', 'cmp', 'edi, VP8_QUANT_INDEX_MAX', '83ff7f'),
  (1663, 'x86_64_vp8_cmp_edx_vp8_luma_mode_b_pred', 'asm_x86_vp8_cmp_edx_vp8_luma_mode_b_pred_exact', 'cmp', 'edx, VP8_LUMA_MODE_B_PRED', '83fa04'),
  (1664, 'x86_64_vp8_imul_eax_vp8_chroma_block_size', 'asm_x86_vp8_imul_eax_vp8_chroma_block_size_exact', 'imul', 'eax, VP8_CHROMA_BLOCK_SIZE', '6bc008'),
  (1665, 'x86_64_vp8_imul_eax_vp8_coeff_block_bytes', 'asm_x86_vp8_imul_eax_vp8_coeff_block_bytes_exact', 'imul', 'eax, VP8_COEFF_BLOCK_BYTES', '6bc020'),
  (1666, 'x86_64_vp8_imul_edx_vp8_bool_reader_size', 'asm_x86_vp8_imul_edx_vp8_bool_reader_size_exact', 'imul', 'edx, VP8_BOOL_READER_SIZE', '6bd220'),
  (1667, 'x86_64_vp8_lea_rax_ptr_rsp_plus_16_plus_vp8_decode_stack_y_plane', 'asm_x86_vp8_lea_rax_ptr_rsp_plus_16_plus_vp8_decode_stack_y_plane_exact', 'lea', 'rax, [rsp + 16 + VP8_DECODE_STACK_Y_PLANE]', '488d8424f9090000'),
  (1668, 'x86_64_vp8_lea_rcx_ptr_rsp_plus_vp8_decode_stack_dequant', 'asm_x86_vp8_lea_rcx_ptr_rsp_plus_vp8_decode_stack_dequant_exact', 'lea', 'rcx, [rsp + VP8_DECODE_STACK_DEQUANT]', '488d8c2481090000'),
  (1669, 'x86_64_vp8_lea_rdi_ptr_rsp_plus_vp8_decode_stack_compressed_plus_vp8_compressed_header_quant', 'asm_x86_vp8_lea_rdi_ptr_rsp_plus_vp8_decode_stack_compressed_plus_vp8_compressed_header_quant_exact', 'lea', 'rdi, [rsp + VP8_DECODE_STACK_COMPRESSED + VP8_COMPRESSED_HEADER_QUANT]', '488d7c2459'),
  (1670, 'x86_64_vp8_lea_rdi_ptr_rsp_plus_vp8_decode_stack_compressed', 'asm_x86_vp8_lea_rdi_ptr_rsp_plus_vp8_decode_stack_compressed_exact', 'lea', 'rdi, [rsp + VP8_DECODE_STACK_COMPRESSED]', '488d7c2420'),
  (1671, 'x86_64_vp8_lea_rdi_ptr_rsp_plus_vp8_decode_stack_residual_context', 'asm_x86_vp8_lea_rdi_ptr_rsp_plus_vp8_decode_stack_residual_context_exact', 'lea', 'rdi, [rsp + VP8_DECODE_STACK_RESIDUAL_CONTEXT]', '488dbc24f59b0000'),
  (1672, 'x86_64_vp8_lea_rdi_ptr_rsp_plus_vp8_decode_stack_top_y', 'asm_x86_vp8_lea_rdi_ptr_rsp_plus_vp8_decode_stack_top_y_exact', 'lea', 'rdi, [rsp + VP8_DECODE_STACK_TOP_Y]', '488dbc24f10b0000'),
  (1673, 'x86_64_vp8_lea_rsi_ptr_rsp_plus_vp8_decode_stack_coeffs', 'asm_x86_vp8_lea_rsi_ptr_rsp_plus_vp8_decode_stack_coeffs_exact', 'lea', 'rsi, [rsp + VP8_DECODE_STACK_COEFFS]', '488db42461060000'),
  (1674, 'x86_64_vp8_lea_rsi_ptr_rsp_plus_vp8_decode_stack_compressed_plus_vp8_compressed_header_segment', 'asm_x86_vp8_lea_rsi_ptr_rsp_plus_vp8_decode_stack_compressed_plus_vp8_compressed_header_segment_exact', 'lea', 'rsi, [rsp + VP8_DECODE_STACK_COMPRESSED + VP8_COMPRESSED_HEADER_SEGMENT]', '488d742440'),
  (1675, 'x86_64_vp8_lea_rsi_ptr_rsp_plus_vp8_decode_stack_top_u', 'asm_x86_vp8_lea_rsi_ptr_rsp_plus_vp8_decode_stack_top_u_exact', 'lea', 'rsi, [rsp + VP8_DECODE_STACK_TOP_U]', '488db424f14b0000'),
  (1676, 'x86_64_vp8_mov_ptr_r15_plus_vp8_macroblock_header_segment_id_al', 'asm_x86_vp8_mov_ptr_r15_plus_vp8_macroblock_header_segment_id_al_exact', 'mov', '[r15 + VP8_MACROBLOCK_HEADER_SEGMENT_ID], al', '418807'),
  (1677, 'x86_64_vp8_mov_eax_ptr_rsp_plus_vp8_decode_stack_mb_y', 'asm_x86_vp8_mov_eax_ptr_rsp_plus_vp8_decode_stack_mb_y_exact', 'mov', 'eax, [rsp + VP8_DECODE_STACK_MB_Y]', '8b8424c50b0000'),
  (1678, 'x86_64_vp8_mov_edi_ptr_rsp_plus_vp8_decode_stack_height', 'asm_x86_vp8_mov_edi_ptr_rsp_plus_vp8_decode_stack_height_exact', 'mov', 'edi, [rsp + VP8_DECODE_STACK_HEIGHT]', '8bbc246d0b0000'),
  (1679, 'x86_64_vp8_mov_edx_vp8_max_chroma_edge', 'asm_x86_vp8_mov_edx_vp8_max_chroma_edge_exact', 'mov', 'edx, VP8_MAX_CHROMA_EDGE', 'ba00200000'),
  (1680, 'x86_64_vp8_mov_esi_vp8_idct_cospi8sqrt2minus1', 'asm_x86_vp8_mov_esi_vp8_idct_cospi8sqrt2minus1_exact', 'mov', 'esi, VP8_IDCT_COSPI8SQRT2MINUS1', 'be7b4e0000'),
  (1681, 'x86_64_vp8_movzx_edx_byte_ptr_rsp_plus_vp8_decode_stack_mb_header_plus_vp8_macroblock_header_luma_mode', 'asm_x86_vp8_movzx_edx_byte_ptr_rsp_plus_vp8_decode_stack_mb_header_plus_vp8_macroblock_header_luma_mode_exact', 'movzx', 'edx, byte [rsp + VP8_DECODE_STACK_MB_HEADER + VP8_MACROBLOCK_HEADER_LUMA_MODE]', '0fb6942409060000'),
  (1682, 'x86_64_vp8_movzx_edx_byte_ptr_rsp_plus_vp8_decode_stack_mb_header_plus_vp8_macroblock_header_segment_id', 'asm_x86_vp8_movzx_edx_byte_ptr_rsp_plus_vp8_decode_stack_mb_header_plus_vp8_macroblock_header_segment_id_exact', 'movzx', 'edx, byte [rsp + VP8_DECODE_STACK_MB_HEADER + VP8_MACROBLOCK_HEADER_SEGMENT_ID]', '0fb6942407060000'),
  (1683, 'x86_64_vp8_sar_eax_vp8_idct_shift', 'asm_x86_vp8_sar_eax_vp8_idct_shift_exact', 'sar', 'eax, VP8_IDCT_SHIFT', 'c1f803'),
  (1684, 'x86_64_exact_lea_r13_ptr_rsp_plus_8', 'asm_x86_exact_lea_r13_ptr_rsp_plus_8_exact', 'lea', 'r13, [rsp + 8]', '4c8d6c2408'),
  (1685, 'x86_64_exact_cmp_r12_2', 'asm_x86_exact_cmp_r12_2_exact', 'cmp', 'r12, 2', '4983fc02'),
  (1686, 'x86_64_exact_mov_edi_stdout_fd', 'asm_x86_exact_mov_edi_stdout_fd_exact', 'mov', 'edi, STDOUT_FD', 'bf01000000'),
  (1687, 'x86_64_exact_mov_edi_stderr_fd', 'asm_x86_exact_mov_edi_stderr_fd_exact', 'mov', 'edi, STDERR_FD', 'bf02000000'),
  (1688, 'x86_64_exact_cmp_byte_ptr_rdi_plus_rax_0', 'asm_x86_exact_cmp_byte_ptr_rdi_plus_rax_0_exact', 'cmp', 'byte [rdi + rax], 0', '803c0700'),
  (1689, 'x86_64_exact_inc_rdx', 'asm_x86_exact_inc_rdx_exact', 'inc', 'rdx', '48ffc2'),
  (1690, 'x86_64_exact_dec_r8d', 'asm_x86_exact_dec_r8d_exact', 'dec', 'r8d', '41ffc8'),
  (1691, 'x86_64_exact_movzx_eax_byte_ptr_rdi_plus_rcx', 'asm_x86_exact_movzx_eax_byte_ptr_rdi_plus_rcx_exact', 'movzx', 'eax, byte [rdi + rcx]', '0fb6040f'),
  (1692, 'x86_64_exact_inc_dword_ptr_rsp_plus_4', 'asm_x86_exact_inc_dword_ptr_rsp_plus_4_exact', 'inc', 'dword [rsp + 4]', 'ff442404'),
  (1693, 'x86_64_exact_sub_esi_edx', 'asm_x86_exact_sub_esi_edx_exact', 'sub', 'esi, edx', '29d6'),
  (1694, 'x86_64_exact_push_1', 'asm_x86_exact_push_1_exact', 'push', '1', '6a01'),
  (1695, 'x86_64_exact_cmp_eax_127', 'asm_x86_exact_cmp_eax_127_exact', 'cmp', 'eax, 127', '83f87f'),
  (1696, 'x86_64_exact_add_eax_5', 'asm_x86_exact_add_eax_5_exact', 'add', 'eax, 5', '83c005'),
  (1697, 'x86_64_exact_add_eax_r9d', 'asm_x86_exact_add_eax_r9d_exact', 'add', 'eax, r9d', '4401c8'),
  (1698, 'x86_64_exact_mov_ptr_r15_eax', 'asm_x86_exact_mov_ptr_r15_eax_exact', 'mov', '[r15], eax', '418907'),
  (1699, 'x86_64_exact_mov_eax_255', 'asm_x86_exact_mov_eax_255_exact', 'mov', 'eax, 255', 'b8ff000000'),
  (1700, 'x86_64_exact_or_eax_r10d', 'asm_x86_exact_or_eax_r10d_exact', 'or', 'eax, r10d', '4409d0'),
  (1701, 'x86_64_exact_mov_r15d_r14d', 'asm_x86_exact_mov_r15d_r14d_exact', 'mov', 'r15d, r14d', '4589f7'),
  (1702, 'x86_64_exact_mov_r8d_ptr_rsp_plus_4', 'asm_x86_exact_mov_r8d_ptr_rsp_plus_4_exact', 'mov', 'r8d, [rsp + 4]', '448b442404'),
  (1703, 'x86_64_exact_movzx_ecx_byte_ptr_rdi_plus_1', 'asm_x86_exact_movzx_ecx_byte_ptr_rdi_plus_1_exact', 'movzx', 'ecx, byte [rdi + 1]', '0fb64f01'),
  (1704, 'x86_64_exact_mov_r9d_r14d', 'asm_x86_exact_mov_r9d_r14d_exact', 'mov', 'r9d, r14d', '4589f1'),
  (1705, 'x86_64_exact_add_ecx_r15d', 'asm_x86_exact_add_ecx_r15d_exact', 'add', 'ecx, r15d', '4401f9'),
  (1706, 'x86_64_exact_add_ebx_ecx', 'asm_x86_exact_add_ebx_ecx_exact', 'add', 'ebx, ecx', '01cb'),
  (1707, 'x86_64_exact_cmp_r15d_r14d', 'asm_x86_exact_cmp_r15d_r14d_exact', 'cmp', 'r15d, r14d', '4539f7'),
  (1708, 'x86_64_exact_imul_eax_r12d', 'asm_x86_exact_imul_eax_r12d_exact', 'imul', 'eax, r12d', '410fafc4'),
  (1709, 'x86_64_exact_mov_ptr_rsp_plus_28_eax', 'asm_x86_exact_mov_ptr_rsp_plus_28_eax_exact', 'mov', '[rsp + 28], eax', '8944241c'),
  (1710, 'x86_64_exact_mov_eax_ptr_rsp_plus_8', 'asm_x86_exact_mov_eax_ptr_rsp_plus_8_exact', 'mov', 'eax, [rsp + 8]', '8b442408'),
  (1711, 'x86_64_exact_mov_ptr_rsp_plus_24_ecx', 'asm_x86_exact_mov_ptr_rsp_plus_24_ecx_exact', 'mov', '[rsp + 24], ecx', '894c2418'),
  (1712, 'x86_64_exact_mov_ecx_ptr_rsp_plus_4', 'asm_x86_exact_mov_ecx_ptr_rsp_plus_4_exact', 'mov', 'ecx, [rsp + 4]', '8b4c2404'),
  (1713, 'x86_64_exact_movzx_eax_dil', 'asm_x86_exact_movzx_eax_dil_exact', 'movzx', 'eax, dil', '400fb6c7'),
  (1714, 'x86_64_exact_mov_ecx_0xffffffff', 'asm_x86_exact_mov_ecx_0xffffffff_exact', 'mov', 'ecx, 0xffffffff', 'b9ffffffff'),
  (1715, 'x86_64_exact_cmp_rbx_r12', 'asm_x86_exact_cmp_rbx_r12_exact', 'cmp', 'rbx, r12', '4c39e3'),
  (1716, 'x86_64_exact_mov_rdi_rbp', 'asm_x86_exact_mov_rdi_rbp_exact', 'mov', 'rdi, rbp', '4889ef'),
  (1717, 'x86_64_exact_cmp_ebx_r12d', 'asm_x86_exact_cmp_ebx_r12d_exact', 'cmp', 'ebx, r12d', '4439e3'),
  (1718, 'x86_64_exact_lea_rdi_ptr_r12_r15', 'asm_x86_exact_lea_rdi_ptr_r12_r15_exact', 'lea', 'rdi, [r12 + r15]', '4b8d3c3c'),
  (1719, 'x86_64_exact_xchg_al_ah', 'asm_x86_exact_xchg_al_ah_exact', 'xchg', 'al, ah', '86e0'),
  (1720, 'x86_64_exact_xchg_ah_al', 'asm_x86_exact_xchg_ah_al_exact', 'xchg', 'ah, al', '86c4'),
  (1721, 'x86_64_exact_lea_rdi_ptr_r12_r13', 'asm_x86_exact_lea_rdi_ptr_r12_r13_exact', 'lea', 'rdi, [r12 + r13]', '4b8d3c2c'),
  (1722, 'x86_64_exact_cmp_r8_rsi', 'asm_x86_exact_cmp_r8_rsi_exact', 'cmp', 'r8, rsi', '4939f0'),
  (1723, 'x86_64_exact_cmp_ebx_esi', 'asm_x86_exact_cmp_ebx_esi_exact', 'cmp', 'ebx, esi', '39f3'),
  (1724, 'x86_64_exact_mov_al_0xc1', 'asm_x86_exact_mov_al_0xc1_exact', 'mov', 'al, 0xC1', 'b0c1'),
  (1725, 'x86_64_exact_mov_esi_192', 'asm_x86_exact_mov_esi_192_exact', 'mov', 'esi, 192', 'bec0000000'),
  (1726, 'x86_64_exact_cmp_r12d_eax', 'asm_x86_exact_cmp_r12d_eax_exact', 'cmp', 'r12d, eax', '4139c4'),
  (1727, 'x86_64_exact_lea_rbx_ptr_rbx_2', 'asm_x86_exact_lea_rbx_ptr_rbx_2_exact', 'lea', 'rbx, [rbx + 2]', '488d5b02'),
  (1728, 'x86_64_exact_lea_rsi_ptr_rsp', 'asm_x86_exact_lea_rsi_ptr_rsp_exact', 'lea', 'rsi, [rsp]', '488d3424'),
  (1729, 'x86_64_exact_mov_al_0xf3', 'asm_x86_exact_mov_al_0xf3_exact', 'mov', 'al, 0xF3', 'b0f3'),
  (1730, 'x86_64_exact_mov_rdi_0x3f8', 'asm_x86_exact_mov_rdi_0x3f8_exact', 'mov', 'rdi, 0x3f8', '48c7c7f8030000'),
  (1731, 'x86_64_exact_movzx_eax_byte_ptr_rsi', 'asm_x86_exact_movzx_eax_byte_ptr_rsi_exact', 'movzx', 'eax, byte [rsi]', '0fb606'),
  (1732, 'x86_64_exact_mov_ptr_r12_rcx_al', 'asm_x86_exact_mov_ptr_r12_rcx_al_exact', 'mov', '[r12 + rcx], al', '4188040c'),
  (1733, 'x86_64_exact_movzx_edx_byte_ptr_rbx', 'asm_x86_exact_movzx_edx_byte_ptr_rbx_exact', 'movzx', 'edx, byte [rbx]', '0fb613'),
  (1734, 'x86_64_exact_mov_esi_10', 'asm_x86_exact_mov_esi_10_exact', 'mov', 'esi, 10', 'be0a000000'),
  (1735, 'x86_64_exact_mov_rax_r9', 'asm_x86_exact_mov_rax_r9_exact', 'mov', 'rax, r9', '4c89c8'),
  (1736, 'x86_64_exact_dec_rsi', 'asm_x86_exact_dec_rsi_exact', 'dec', 'rsi', '48ffce'),
  (1737, 'x86_64_exact_cmp_rbx_r13', 'asm_x86_exact_cmp_rbx_r13_exact', 'cmp', 'rbx, r13', '4c39eb'),
  (1738, 'x86_64_exact_movzx_eax_byte_ptr_r12', 'asm_x86_exact_movzx_eax_byte_ptr_r12_exact', 'movzx', 'eax, byte [r12]', '410fb60424'),
  (1739, 'x86_64_exact_mov_cl_0xc0', 'asm_x86_exact_mov_cl_0xc0_exact', 'mov', 'cl, 0xC0', 'b1c0'),
  (1740, 'x86_64_exact_mov_rax_r10', 'asm_x86_exact_mov_rax_r10_exact', 'mov', 'rax, r10', '4c89d0'),
  (1741, 'x86_64_exact_cmp_rax_1', 'asm_x86_exact_cmp_rax_1_exact', 'cmp', 'rax, 1', '4883f801'),
  (1742, 'x86_64_exact_cmp_r12_r13', 'asm_x86_exact_cmp_r12_r13_exact', 'cmp', 'r12, r13', '4d39ec'),
  (1743, 'x86_64_exact_mov_al_0x89', 'asm_x86_exact_mov_al_0x89_exact', 'mov', 'al, 0x89', 'b089'),
  (1744, 'x86_64_exact_rdtsc', 'asm_x86_exact_rdtsc_exact', 'rdtsc', '', '0f31'),
  (1745, 'x86_64_exact_cmp_rax_3', 'asm_x86_exact_cmp_rax_3_exact', 'cmp', 'rax, 3', '4883f803'),
  (1746, 'x86_64_exact_test_r9_r9', 'asm_x86_exact_test_r9_r9_exact', 'test', 'r9, r9', '4d85c9'),
  (1747, 'x86_64_exact_movzx_eax_byte_ptr_r12_rcx', 'asm_x86_exact_movzx_eax_byte_ptr_r12_rcx_exact', 'movzx', 'eax, byte [r12 + rcx]', '410fb6040c'),
  (1748, 'x86_64_exact_and_eax_1', 'asm_x86_exact_and_eax_1_exact', 'and', 'eax, 1', '83e001'),
  (1749, 'x86_64_exact_dec_esi', 'asm_x86_exact_dec_esi_exact', 'dec', 'esi', 'ffce'),
  (1750, 'x86_64_exact_or_ecx_eax', 'asm_x86_exact_or_ecx_eax_exact', 'or', 'ecx, eax', '09c1'),
  (1751, 'x86_64_exact_mov_rdi_ptr_r13_16', 'asm_x86_exact_mov_rdi_ptr_r13_16_exact', 'mov', 'rdi, [r13 + 16]', '498b7d10'),
  (1752, 'x86_64_exact_cmp_rbx_r15', 'asm_x86_exact_cmp_rbx_r15_exact', 'cmp', 'rbx, r15', '4c39fb'),
  (1753, 'x86_64_exact_out_dx_ax', 'asm_x86_exact_out_dx_ax_exact', 'out', 'dx, ax', '66ef'),
  (1754, 'x86_64_exact_movzx_eax_byte_ptr_r10_rax', 'asm_x86_exact_movzx_eax_byte_ptr_r10_rax_exact', 'movzx', 'eax, byte [r10 + rax]', '410fb60402'),
  (1755, 'x86_64_exact_mov_edx_20', 'asm_x86_exact_mov_edx_20_exact', 'mov', 'edx, 20', 'ba14000000'),
  (1756, 'x86_64_exact_mov_r9d_1', 'asm_x86_exact_mov_r9d_1_exact', 'mov', 'r9d, 1', '41b901000000'),
  (1757, 'x86_64_exact_dec_r12', 'asm_x86_exact_dec_r12_exact', 'dec', 'r12', '49ffcc'),
  (1758, 'x86_64_exact_shr_rax_32', 'asm_x86_exact_shr_rax_32_exact', 'shr', 'rax, 32', '48c1e820'),
  (1759, 'x86_64_exact_mov_rsi_r10', 'asm_x86_exact_mov_rsi_r10_exact', 'mov', 'rsi, r10', '4c89d6'),
  (1760, 'x86_64_exact_add_rdi_4', 'asm_x86_exact_add_rdi_4_exact', 'add', 'rdi, 4', '4883c704'),
  (1761, 'x86_64_exact_add_rsp_4', 'asm_x86_exact_add_rsp_4_exact', 'add', 'rsp, 4', '4883c404'),
  (1762, 'x86_64_exact_movzx_eax_byte_ptr_rbx', 'asm_x86_exact_movzx_eax_byte_ptr_rbx_exact', 'movzx', 'eax, byte [rbx]', '0fb603'),
  (1763, 'x86_64_exact_mov_al_0x0a', 'asm_x86_exact_mov_al_0x0a_exact', 'mov', 'al, 0x0A', 'b00a'),
  (1764, 'x86_64_exact_dec_r10', 'asm_x86_exact_dec_r10_exact', 'dec', 'r10', '49ffca'),
  (1765, 'x86_64_exact_mov_al_0x04', 'asm_x86_exact_mov_al_0x04_exact', 'mov', 'al, 0x04', 'b004'),
  (1766, 'x86_64_exact_xor_rcx_rcx', 'asm_x86_exact_xor_rcx_rcx_exact', 'xor', 'rcx, rcx', '4831c9'),
  (1767, 'x86_64_exact_or_al_32', 'asm_x86_exact_or_al_32_exact', 'or', 'al, 32', '0c20'),
  (1768, 'x86_64_exact_sub_edi_eax', 'asm_x86_exact_sub_edi_eax_exact', 'sub', 'edi, eax', '29c7'),
  (1769, 'x86_64_exact_xor_ebp_ebp', 'asm_x86_exact_xor_ebp_ebp_exact', 'xor', 'ebp, ebp', '31ed'),
  (1770, 'x86_64_exact_shl_edx_4', 'asm_x86_exact_shl_edx_4_exact', 'shl', 'edx, 4', 'c1e204'),
  (1771, 'x86_64_exact_mov_ecx_ptr_rsp_24', 'asm_x86_exact_mov_ecx_ptr_rsp_24_exact', 'mov', 'ecx, [rsp + 24]', '8b4c2418'),
  (1772, 'x86_64_exact_cmp_rax_rsi', 'asm_x86_exact_cmp_rax_rsi_exact', 'cmp', 'rax, rsi', '4839f0'),
  (1773, 'x86_64_exact_mov_edx_ptr_rsp_8', 'asm_x86_exact_mov_edx_ptr_rsp_8_exact', 'mov', 'edx, [rsp + 8]', '8b542408'),
  (1774, 'x86_64_exact_mov_r14d_esi', 'asm_x86_exact_mov_r14d_esi_exact', 'mov', 'r14d, esi', '4189f6'),
  (1775, 'x86_64_exact_cmp_rax_r14', 'asm_x86_exact_cmp_rax_r14_exact', 'cmp', 'rax, r14', '4c39f0'),
  (1776, 'x86_64_exact_cmp_al_13', 'asm_x86_exact_cmp_al_13_exact', 'cmp', 'al, 13', '3c0d'),
  (1777, 'x86_64_exact_add_rax_rdx', 'asm_x86_exact_add_rax_rdx_exact', 'add', 'rax, rdx', '4801d0'),
  (1778, 'x86_64_exact_shl_rax_4', 'asm_x86_exact_shl_rax_4_exact', 'shl', 'rax, 4', '48c1e004'),
  (1779, 'x86_64_exact_mov_rsi_r8', 'asm_x86_exact_mov_rsi_r8_exact', 'mov', 'rsi, r8', '4c89c6'),
  (1780, 'x86_64_exact_add_rsp_3', 'asm_x86_exact_add_rsp_3_exact', 'add', 'rsp, 3', '4883c403'),
  (1781, 'x86_64_exact_lea_rsi_ptr_rsp_160', 'asm_x86_exact_lea_rsi_ptr_rsp_160_exact', 'lea', 'rsi, [rsp + 160]', '488db424a0000000'),
  (1782, 'x86_64_exact_add_eax_r11d', 'asm_x86_exact_add_eax_r11d_exact', 'add', 'eax, r11d', '4401d8'),
  (1783, 'x86_64_exact_sar_eax_7', 'asm_x86_exact_sar_eax_7_exact', 'sar', 'eax, 7', 'c1f807'),
  (1784, 'x86_64_exact_add_r13_rax', 'asm_x86_exact_add_r13_rax_exact', 'add', 'r13, rax', '4901c5'),
  (1785, 'x86_64_exact_mov_eax_ptr_rsp_28', 'asm_x86_exact_mov_eax_ptr_rsp_28_exact', 'mov', 'eax, [rsp + 28]', '8b44241c'),
  (1786, 'x86_64_exact_cmp_eax_ptr_rsp_4', 'asm_x86_exact_cmp_eax_ptr_rsp_4_exact', 'cmp', 'eax, [rsp + 4]', '3b442404'),
  (1787, 'x86_64_exact_and_ecx_7', 'asm_x86_exact_and_ecx_7_exact', 'and', 'ecx, 7', '83e107'),
  (1788, 'x86_64_exact_inc_r9', 'asm_x86_exact_inc_r9_exact', 'inc', 'r9', '49ffc1'),
  (1789, 'x86_64_exact_imul_eax_ebx', 'asm_x86_exact_imul_eax_ebx_exact', 'imul', 'eax, ebx', '0fafc3'),
  (1790, 'x86_64_exact_mov_eax_ebp', 'asm_x86_exact_mov_eax_ebp_exact', 'mov', 'eax, ebp', '89e8'),
  (1791, 'x86_64_exact_cmp_qword_ptr_rbp_16_0', 'asm_x86_exact_cmp_qword_ptr_rbp_16_0_exact', 'cmp', 'qword [rbp + 16], 0', '48837d1000'),
  (1792, 'x86_64_exact_mov_ptr_rbp_48_r9', 'asm_x86_exact_mov_ptr_rbp_48_r9_exact', 'mov', '[rbp - 48], r9', '4c894dd0'),
  (1793, 'x86_64_exact_cmp_rdi_rsi', 'asm_x86_exact_cmp_rdi_rsi_exact', 'cmp', 'rdi, rsi', '4839f7'),
  (1794, 'x86_64_exact_and_eax_0xff', 'asm_x86_exact_and_eax_0xff_exact', 'and', 'eax, 0xFF', '25ff000000'),
  (1795, 'x86_64_exact_mov_r10_ptr_rbp_112', 'asm_x86_exact_mov_r10_ptr_rbp_112_exact', 'mov', 'r10, [rbp - 112]', '4c8b5590'),
  (1796, 'x86_64_exact_mov_r13_ptr_rsp_16', 'asm_x86_exact_mov_r13_ptr_rsp_16_exact', 'mov', 'r13, [rsp + 16]', '4c8b6c2410'),
  (1797, 'x86_64_exact_sub_esi_r15d', 'asm_x86_exact_sub_esi_r15d_exact', 'sub', 'esi, r15d', '4429fe'),
  (1798, 'x86_64_exact_mov_al_0xf2', 'asm_x86_exact_mov_al_0xf2_exact', 'mov', 'al, 0xF2', 'b0f2'),
  (1799, 'x86_64_exact_mov_ptr_rbp_64_r10', 'asm_x86_exact_mov_ptr_rbp_64_r10_exact', 'mov', '[rbp - 64], r10', '4c8955c0'),
  (1800, 'x86_64_exact_lea_rdi_ptr_rsp_96', 'asm_x86_exact_lea_rdi_ptr_rsp_96_exact', 'lea', 'rdi, [rsp + 96]', '488d7c2460'),
  (1801, 'x86_64_exact_movzx_esi_r13b', 'asm_x86_exact_movzx_esi_r13b_exact', 'movzx', 'esi, r13b', '410fb6f5'),
  (1802, 'x86_64_exact_lea_rdi_ptr_rsp_480', 'asm_x86_exact_lea_rdi_ptr_rsp_480_exact', 'lea', 'rdi, [rsp + 480]', '488dbc24e0010000'),
  (1803, 'x86_64_exact_add_eax_3', 'asm_x86_exact_add_eax_3_exact', 'add', 'eax, 3', '83c003'),
  (1804, 'x86_64_exact_lea_rsi_ptr_rsp_32', 'asm_x86_exact_lea_rsi_ptr_rsp_32_exact', 'lea', 'rsi, [rsp + 32]', '488d742420'),
  (1805, 'x86_64_exact_add_rdi_2', 'asm_x86_exact_add_rdi_2_exact', 'add', 'rdi, 2', '4883c702'),
  (1806, 'x86_64_exact_mov_ptr_rsp_12_eax', 'asm_x86_exact_mov_ptr_rsp_12_eax_exact', 'mov', '[rsp + 12], eax', '8944240c'),
  (1807, 'x86_64_exact_add_eax_63', 'asm_x86_exact_add_eax_63_exact', 'add', 'eax, 63', '83c03f'),
  (1808, 'x86_64_exact_mov_byte_ptr_rbx_0', 'asm_x86_exact_mov_byte_ptr_rbx_0_exact', 'mov', 'byte [rbx], 0', 'c60300'),
  (1809, 'x86_64_exact_dec_r12d', 'asm_x86_exact_dec_r12d_exact', 'dec', 'r12d', '41ffcc'),
  (1810, 'x86_64_exact_test_r12d_r12d', 'asm_x86_exact_test_r12d_r12d_exact', 'test', 'r12d, r12d', '4585e4'),
  (1811, 'x86_64_exact_mov_r9d_3', 'asm_x86_exact_mov_r9d_3_exact', 'mov', 'r9d, 3', '41b903000000'),
  (1812, 'x86_64_exact_push_0', 'asm_x86_exact_push_0_exact', 'push', '0', '6a00'),
  (1813, 'x86_64_exact_mov_ptr_rbx_eax', 'asm_x86_exact_mov_ptr_rbx_eax_exact', 'mov', '[rbx], eax', '8903'),
  (1814, 'x86_64_exact_lea_r9_ptr_rbx_1', 'asm_x86_exact_lea_r9_ptr_rbx_1_exact', 'lea', 'r9, [rbx + 1]', '4c8d4b01'),
  (1815, 'x86_64_exact_cmp_r9d_eax', 'asm_x86_exact_cmp_r9d_eax_exact', 'cmp', 'r9d, eax', '4139c1'),
  (1816, 'x86_64_exact_mov_al_0x8b', 'asm_x86_exact_mov_al_0x8b_exact', 'mov', 'al, 0x8B', 'b08b'),
  (1817, 'x86_64_exact_mov_ch_0', 'asm_x86_exact_mov_ch_0_exact', 'mov', 'ch, 0', 'b500'),
  (1818, 'x86_64_exact_mov_eax_ptr_rdi_12', 'asm_x86_exact_mov_eax_ptr_rdi_12_exact', 'mov', 'eax, [rdi + 12]', '8b470c'),
  (1819, 'x86_64_exact_mov_al_sil', 'asm_x86_exact_mov_al_sil_exact', 'mov', 'al, sil', '4088f0'),
  (1820, 'x86_64_exact_mov_ch_0x2a', 'asm_x86_exact_mov_ch_0x2a_exact', 'mov', 'ch, 0x2A', 'b52a'),
  (1821, 'x86_64_exact_mov_r10_ptr_rbp_64', 'asm_x86_exact_mov_r10_ptr_rbp_64_exact', 'mov', 'r10, [rbp - 64]', '4c8b55c0'),
  (1822, 'x86_64_exact_mov_rdi_ptr_rbp_64', 'asm_x86_exact_mov_rdi_ptr_rbp_64_exact', 'mov', 'rdi, [rbp - 64]', '488b7dc0'),
  (1823, 'x86_64_exact_shr_r10_51', 'asm_x86_exact_shr_r10_51_exact', 'shr', 'r10, 51', '49c1ea33'),
  (1824, 'x86_64_exact_or_ebx_edi', 'asm_x86_exact_or_ebx_edi_exact', 'or', 'ebx, edi', '09fb'),
  (1825, 'x86_64_exact_add_r12_ptr_rsp_8', 'asm_x86_exact_add_r12_ptr_rsp_8_exact', 'add', 'r12, [rsp + 8]', '4c03642408'),
  (1826, 'x86_64_exact_mov_ptr_rsp_4_eax', 'asm_x86_exact_mov_ptr_rsp_4_eax_exact', 'mov', '[rsp + 4], eax', '89442404'),
  (1827, 'x86_64_exact_mov_r8_r15', 'asm_x86_exact_mov_r8_r15_exact', 'mov', 'r8, r15', '4d89f8'),
  (1828, 'x86_64_exact_mov_r9d_ptr_rsp_60', 'asm_x86_exact_mov_r9d_ptr_rsp_60_exact', 'mov', 'r9d, [rsp + 60]', '448b4c243c'),
  (1829, 'x86_64_exact_cmp_eax_32', 'asm_x86_exact_cmp_eax_32_exact', 'cmp', 'eax, 32', '83f820'),
  (1830, 'x86_64_exact_mov_eax_ptr_rsp_16', 'asm_x86_exact_mov_eax_ptr_rsp_16_exact', 'mov', 'eax, [rsp + 16]', '8b442410'),
  (1831, 'x86_64_exact_cmp_al_9', 'asm_x86_exact_cmp_al_9_exact', 'cmp', 'al, 9', '3c09'),
  (1832, 'x86_64_exact_mov_r14d_1', 'asm_x86_exact_mov_r14d_1_exact', 'mov', 'r14d, 1', '41be01000000'),
  (1833, 'x86_64_exact_mov_r8d_8', 'asm_x86_exact_mov_r8d_8_exact', 'mov', 'r8d, 8', '41b808000000');

insert into asm_exact_fixed_encoding_fact(encoding_id, isa_id, name, rule_name, op_name, operand_text, fixed_hex) values
  (1834, 4, 'arm32_exact_popne_pc', 'asm_arm32_exact_popne_pc_exact', 'popne', '{pc}', '04f09d14'),
  (1835, 4, 'arm32_exact_str_r0_ptr_r1', 'asm_arm32_exact_str_r0_ptr_r1_exact', 'str', 'r0, [r1]', '000081e5'),
  (1836, 4, 'arm32_exact_ldr_r0_ptr_r1', 'asm_arm32_exact_ldr_r0_ptr_r1_exact', 'ldr', 'r0, [r1]', '000091e5'),
  (1837, 4, 'arm32_exact_movne_r0_imm_1', 'asm_arm32_exact_movne_r0_imm_1_exact', 'movne', 'r0, #1', '0100a013'),
  (1838, 4, 'arm32_exact_popne_r4_pc', 'asm_arm32_exact_popne_r4_pc_exact', 'popne', '{r4, pc}', '1080bd18'),
  (1839, 4, 'arm32_exact_ldr_r0_ptr_r4_r0', 'asm_arm32_exact_ldr_r0_ptr_r4_r0_exact', 'ldr', 'r0, [r4, r0]', '000094e7'),
  (1840, 4, 'arm32_exact_cmp_r4_r0', 'asm_arm32_exact_cmp_r4_r0_exact', 'cmp', 'r4, r0', '000054e1'),
  (1841, 4, 'arm32_exact_pop_r4_r5_r6_pc', 'asm_arm32_exact_pop_r4_r5_r6_pc_exact', 'pop', '{r4, r5, r6, pc}', '7080bde8'),
  (1842, 4, 'arm32_exact_popne_r4_r5_r6_r7_pc', 'asm_arm32_exact_popne_r4_r5_r6_r7_pc_exact', 'popne', '{r4, r5, r6, r7, pc}', 'f080bd18'),
  (1843, 4, 'arm32_exact_cmp_r0_r4', 'asm_arm32_exact_cmp_r0_r4_exact', 'cmp', 'r0, r4', '040050e1'),
  (1844, 4, 'arm32_exact_pop_r4_r5_r6_r7_pc', 'asm_arm32_exact_pop_r4_r5_r6_r7_pc_exact', 'pop', '{r4, r5, r6, r7, pc}', 'f080bde8'),
  (1845, 4, 'arm32_exact_pop_r4_r5_r6_r7_r8_r9_r10_r11_pc', 'asm_arm32_exact_pop_r4_r5_r6_r7_r8_r9_r10_r11_pc_exact', 'pop', '{r4, r5, r6, r7, r8, r9, r10, r11, pc}', 'f08fbde8'),
  (1846, 4, 'arm32_exact_subs_r5_r5_imm_1', 'asm_arm32_exact_subs_r5_r5_imm_1_exact', 'subs', 'r5, r5, #1', '015055e2'),
  (1847, 4, 'arm32_exact_moveq_r0_imm_0', 'asm_arm32_exact_moveq_r0_imm_0_exact', 'moveq', 'r0, #0', '0000a003'),
  (1848, 4, 'arm32_exact_bxeq_lr', 'asm_arm32_exact_bxeq_lr_exact', 'bxeq', 'lr', '1eff2f01'),
  (1849, 4, 'arm32_exact_ldr_r0_ptr_r2', 'asm_arm32_exact_ldr_r0_ptr_r2_exact', 'ldr', 'r0, [r2]', '000092e5'),
  (1850, 4, 'arm32_exact_ldr_r3_ptr_r2', 'asm_arm32_exact_ldr_r3_ptr_r2_exact', 'ldr', 'r3, [r2]', '003092e5'),
  (1851, 4, 'arm32_exact_popne_r4_r5_pc', 'asm_arm32_exact_popne_r4_r5_pc_exact', 'popne', '{r4, r5, pc}', '3080bd18'),
  (1852, 4, 'arm32_exact_cmp_r3_imm_0', 'asm_arm32_exact_cmp_r3_imm_0_exact', 'cmp', 'r3, #0', '000053e3'),
  (1853, 4, 'arm32_exact_push_r4_r5_lr', 'asm_arm32_exact_push_r4_r5_lr_exact', 'push', '{r4, r5, lr}', '30402de9'),
  (1854, 4, 'arm32_exact_add_sp_sp_imm_16', 'asm_arm32_exact_add_sp_sp_imm_16_exact', 'add', 'sp, sp, #16', '10d08de2'),
  (1855, 4, 'arm32_exact_str_r3_ptr_r2', 'asm_arm32_exact_str_r3_ptr_r2_exact', 'str', 'r3, [r2]', '003082e5'),
  (1856, 4, 'arm32_exact_ldr_r0_ptr_r0', 'asm_arm32_exact_ldr_r0_ptr_r0_exact', 'ldr', 'r0, [r0]', '000090e5'),
  (1857, 4, 'arm32_exact_push_r4_r5_r6_lr', 'asm_arm32_exact_push_r4_r5_r6_lr_exact', 'push', '{r4, r5, r6, lr}', '70402de9'),
  (1858, 4, 'arm32_exact_cmp_r5_imm_0', 'asm_arm32_exact_cmp_r5_imm_0_exact', 'cmp', 'r5, #0', '000055e3'),
  (1859, 4, 'arm32_exact_cmp_r1_r2', 'asm_arm32_exact_cmp_r1_r2_exact', 'cmp', 'r1, r2', '020051e1'),
  (1860, 4, 'arm32_exact_str_r1_ptr_r2_r0', 'asm_arm32_exact_str_r1_ptr_r2_r0_exact', 'str', 'r1, [r2, r0]', '001082e7'),
  (1861, 4, 'arm32_exact_str_r0_ptr_r1_imm_4', 'asm_arm32_exact_str_r0_ptr_r1_imm_4_exact', 'str', 'r0, [r1, #4]', '040081e5'),
  (1862, 4, 'arm32_exact_cmp_r1_imm_0', 'asm_arm32_exact_cmp_r1_imm_0_exact', 'cmp', 'r1, #0', '000051e3'),
  (1863, 4, 'arm32_exact_add_sp_sp_imm_8', 'asm_arm32_exact_add_sp_sp_imm_8_exact', 'add', 'sp, sp, #8', '08d08de2'),
  (1864, 4, 'arm32_exact_cmp_r7_imm_0', 'asm_arm32_exact_cmp_r7_imm_0_exact', 'cmp', 'r7, #0', '000057e3'),
  (1865, 4, 'arm32_exact_ldr_r0_ptr_r1_imm_4', 'asm_arm32_exact_ldr_r0_ptr_r1_imm_4_exact', 'ldr', 'r0, [r1, #4]', '040091e5');

insert into asm_exact_fixed_encoding_fact(encoding_id, name, rule_name, op_name, operand_text, fixed_hex) values
  (1866, 'x86_64_exact_bswap_rax', 'asm_x86_exact_bswap_rax_exact', 'bswap', 'rax', '480fc8'),
  (1867, 'x86_64_exact_add_rsi_rax', 'asm_x86_exact_add_rsi_rax_exact', 'add', 'rsi, rax', '4801c6'),
  (1868, 'x86_64_exact_cmp_eax_6', 'asm_x86_exact_cmp_eax_6_exact', 'cmp', 'eax, 6', '83f806'),
  (1869, 'x86_64_exact_cmp_qword_ptr_rbp_48_0', 'asm_x86_exact_cmp_qword_ptr_rbp_48_0_exact', 'cmp', 'qword [rbp - 48], 0', '48837dd000'),
  (1870, 'x86_64_exact_cmp_rax_r13', 'asm_x86_exact_cmp_rax_r13_exact', 'cmp', 'rax, r13', '4c39e8'),
  (1871, 'x86_64_exact_cmp_rbx_rsi', 'asm_x86_exact_cmp_rbx_rsi_exact', 'cmp', 'rbx, rsi', '4839f3'),
  (1872, 'x86_64_exact_mov_al_cl', 'asm_x86_exact_mov_al_cl_exact', 'mov', 'al, cl', '88c8'),
  (1873, 'x86_64_exact_mov_eax_127', 'asm_x86_exact_mov_eax_127_exact', 'mov', 'eax, 127', 'b87f000000'),
  (1874, 'x86_64_exact_mov_edx_256', 'asm_x86_exact_mov_edx_256_exact', 'mov', 'edx, 256', 'ba00010000'),
  (1875, 'x86_64_exact_mov_edx_edx', 'asm_x86_exact_mov_edx_edx_exact', 'mov', 'edx, edx', '89d2'),
  (1876, 'x86_64_exact_mov_r9_rax', 'asm_x86_exact_mov_r9_rax_exact', 'mov', 'r9, rax', '4989c1'),
  (1877, 'x86_64_exact_mov_rdi_r9', 'asm_x86_exact_mov_rdi_r9_exact', 'mov', 'rdi, r9', '4c89cf'),
  (1878, 'x86_64_exact_mov_rdx_r11', 'asm_x86_exact_mov_rdx_r11_exact', 'mov', 'rdx, r11', '4c89da'),
  (1879, 'x86_64_exact_or_eax_ebx', 'asm_x86_exact_or_eax_ebx_exact', 'or', 'eax, ebx', '09d8'),
  (1880, 'x86_64_exact_shr_eax_cl', 'asm_x86_exact_shr_eax_cl_exact', 'shr', 'eax, cl', 'd3e8'),
  (1881, 'x86_64_exact_sub_rax_r12', 'asm_x86_exact_sub_rax_r12_exact', 'sub', 'rax, r12', '4c29e0'),
  (1882, 'x86_64_exact_test_eax_1', 'asm_x86_exact_test_eax_1_exact', 'test', 'eax, 1', 'a901000000'),
  (1883, 'x86_64_exact_test_r13_r13', 'asm_x86_exact_test_r13_r13_exact', 'test', 'r13, r13', '4d85ed'),
  (1884, 'x86_64_exact_cmp_eax_7', 'asm_x86_exact_cmp_eax_7_exact', 'cmp', 'eax, 7', '83f807'),
  (1885, 'x86_64_exact_cmp_r13d_r12d', 'asm_x86_exact_cmp_r13d_r12d_exact', 'cmp', 'r13d, r12d', '4539e5'),
  (1886, 'x86_64_exact_cmp_r9_r12', 'asm_x86_exact_cmp_r9_r12_exact', 'cmp', 'r9, r12', '4d39e1'),
  (1887, 'x86_64_exact_cmp_rax_r15', 'asm_x86_exact_cmp_rax_r15_exact', 'cmp', 'rax, r15', '4c39f8'),
  (1888, 'x86_64_exact_dec_r11', 'asm_x86_exact_dec_r11_exact', 'dec', 'r11', '49ffcb'),
  (1889, 'x86_64_exact_lea_rdi_ptr_rsp_352', 'asm_x86_exact_lea_rdi_ptr_rsp_352_exact', 'lea', 'rdi, [rsp + 352]', '488dbc2460010000'),
  (1890, 'x86_64_exact_mov_al_0x66', 'asm_x86_exact_mov_al_0x66_exact', 'mov', 'al, 0x66', 'b066'),
  (1891, 'x86_64_exact_mov_al_0xc8', 'asm_x86_exact_mov_al_0xc8_exact', 'mov', 'al, 0xC8', 'b0c8'),
  (1892, 'x86_64_exact_mov_byte_ptr_rdi_al', 'asm_x86_exact_mov_byte_ptr_rdi_al_exact', 'mov', 'byte [rdi], al', '8807'),
  (1893, 'x86_64_exact_mov_cl_0xc1', 'asm_x86_exact_mov_cl_0xc1_exact', 'mov', 'cl, 0xC1', 'b1c1'),
  (1894, 'x86_64_exact_mov_dx_r8w', 'asm_x86_exact_mov_dx_r8w_exact', 'mov', 'dx, r8w', '664489c2'),
  (1895, 'x86_64_exact_mov_eax_ptr_rdi', 'asm_x86_exact_mov_eax_ptr_rdi_exact', 'mov', 'eax, [rdi]', '8b07'),
  (1896, 'x86_64_exact_mov_eax_ptr_rsp_32', 'asm_x86_exact_mov_eax_ptr_rsp_32_exact', 'mov', 'eax, [rsp + 32]', '8b442420'),
  (1897, 'x86_64_exact_mov_ecx_200000', 'asm_x86_exact_mov_ecx_200000_exact', 'mov', 'ecx, 200000', 'b9400d0300'),
  (1898, 'x86_64_exact_mov_ecx_500', 'asm_x86_exact_mov_ecx_500_exact', 'mov', 'ecx, 500', 'b9f4010000'),
  (1899, 'x86_64_exact_mov_edi_ptr_rsp_36', 'asm_x86_exact_mov_edi_ptr_rsp_36_exact', 'mov', 'edi, [rsp + 36]', '8b7c2424'),
  (1900, 'x86_64_exact_mov_edi_ecx', 'asm_x86_exact_mov_edi_ecx_exact', 'mov', 'edi, ecx', '89cf'),
  (1901, 'x86_64_exact_mov_esi_0', 'asm_x86_exact_mov_esi_0_exact', 'mov', 'esi, 0', 'be00000000'),
  (1902, 'x86_64_exact_mov_r13w_si', 'asm_x86_exact_mov_r13w_si_exact', 'mov', 'r13w, si', '664189f5'),
  (1903, 'x86_64_exact_mov_r15_r9', 'asm_x86_exact_mov_r15_r9_exact', 'mov', 'r15, r9', '4d89cf'),
  (1904, 'x86_64_exact_mov_r8b_0', 'asm_x86_exact_mov_r8b_0_exact', 'mov', 'r8b, 0', '41b000'),
  (1905, 'x86_64_exact_mov_r9d_4', 'asm_x86_exact_mov_r9d_4_exact', 'mov', 'r9d, 4', '41b904000000');

insert into asm_exact_fixed_encoding_fact(encoding_id, isa_id, name, rule_name, op_name, operand_text, fixed_hex) values
  (1906, 4, 'arm32_exact_mov_r5_r1', 'asm_arm32_exact_mov_r5_r1_exact', 'mov', 'r5, r1', '0150a0e1'),
  (1907, 4, 'arm32_exact_and_r1_r1_imm_0xff', 'asm_arm32_exact_and_r1_r1_imm_0xff_exact', 'and', 'r1, r1, #0xff', 'ff1001e2'),
  (1908, 4, 'arm32_exact_cmp_r6_imm_0', 'asm_arm32_exact_cmp_r6_imm_0_exact', 'cmp', 'r6, #0', '000056e3'),
  (1909, 4, 'arm32_exact_mov_r6_r2', 'asm_arm32_exact_mov_r6_r2_exact', 'mov', 'r6, r2', '0260a0e1'),
  (1910, 4, 'arm32_exact_streq_r1_ptr_r2', 'asm_arm32_exact_streq_r1_ptr_r2_exact', 'streq', 'r1, [r2]', '00108205'),
  (1911, 4, 'arm32_exact_mov_r0_r5', 'asm_arm32_exact_mov_r0_r5_exact', 'mov', 'r0, r5', '0500a0e1'),
  (1912, 4, 'arm32_exact_mov_r2_imm_0', 'asm_arm32_exact_mov_r2_imm_0_exact', 'mov', 'r2, #0', '0020a0e3'),
  (2163, 4, 'arm32_exact_mov_r11_r9', 'asm_arm32_exact_mov_r11_r9_exact', 'mov', 'r11, r9', '09b0a0e1');

insert into asm_exact_fixed_encoding_fact(encoding_id, name, rule_name, op_name, operand_text, fixed_hex) values
  (1913, 'x86_64_exact_add_al_digit_0', 'asm_x86_exact_add_al_digit_0_exact', 'add', 'al, ''0''', '0430'),
  (1914, 'x86_64_exact_cmp_al_a', 'asm_x86_exact_cmp_al_a_exact', 'cmp', 'al, ''a''', '3c61'),
  (1915, 'x86_64_exact_cmp_al_space', 'asm_x86_exact_cmp_al_space_exact', 'cmp', 'al, '' ''', '3c20'),
  (1916, 'x86_64_exact_cmp_al_slash', 'asm_x86_exact_cmp_al_slash_exact', 'cmp', 'al, ''/''', '3c2f'),
  (1917, 'x86_64_exact_cmp_byte_ptr_r9_slash', 'asm_x86_exact_cmp_byte_ptr_r9_slash_exact', 'cmp', 'byte [r9], ''/''', '4180392f'),
  (1918, 'x86_64_exact_cmp_al_digit_0', 'asm_x86_exact_cmp_al_digit_0_exact', 'cmp', 'al, ''0''', '3c30'),
  (1919, 'x86_64_exact_mov_rax_rdx', 'asm_x86_exact_mov_rax_rdx_exact', 'mov', 'rax, rdx', '4889d0'),
  (1920, 'x86_64_exact_mov_rcx_0x8000000000000000', 'asm_x86_exact_mov_rcx_0x8000000000000000_exact', 'mov', 'rcx, 0x8000000000000000', '48b90000000000000080'),
  (1921, 'x86_64_exact_mov_rcx_r8', 'asm_x86_exact_mov_rcx_r8_exact', 'mov', 'rcx, r8', '4c89c1'),
  (1922, 'x86_64_exact_mov_rcx_rbx', 'asm_x86_exact_mov_rcx_rbx_exact', 'mov', 'rcx, rbx', '4889d9'),
  (1923, 'x86_64_exact_mov_rdi_ptr_r13_rbx_1_8', 'asm_x86_exact_mov_rdi_ptr_r13_rbx_1_8_exact', 'mov', 'rdi, [r13 + (rbx - 1) * 8]', '498b7cddf8'),
  (1924, 'x86_64_exact_mov_rsi_ptr_r13_24', 'asm_x86_exact_mov_rsi_ptr_r13_24_exact', 'mov', 'rsi, [r13 + 24]', '498b7518'),
  (1925, 'x86_64_exact_mov_sil_colon', 'asm_x86_exact_mov_sil_colon_exact', 'mov', 'sil, '':''', '40b63a'),
  (1926, 'x86_64_exact_sar_eax_3', 'asm_x86_exact_sar_eax_3_exact', 'sar', 'eax, 3', 'c1f803'),
  (1927, 'x86_64_exact_sete_al', 'asm_x86_exact_sete_al_exact', 'sete', 'al', '0f94d0'),
  (1928, 'x86_64_exact_shl_ebx_3', 'asm_x86_exact_shl_ebx_3_exact', 'shl', 'ebx, 3', 'c1e303'),
  (1929, 'x86_64_exact_sub_rax_4', 'asm_x86_exact_sub_rax_4_exact', 'sub', 'rax, 4', '4883e804'),
  (1930, 'x86_64_exact_sub_rsp_48', 'asm_x86_exact_sub_rsp_48_exact', 'sub', 'rsp, 48', '4883ec30'),
  (1931, 'x86_64_exact_add_eax_257', 'asm_x86_exact_add_eax_257_exact', 'add', 'eax, 257', '0501010000'),
  (1932, 'x86_64_exact_add_rax_r10', 'asm_x86_exact_add_rax_r10_exact', 'add', 'rax, r10', '4c01d0'),
  (1933, 'x86_64_exact_add_rax_rdi', 'asm_x86_exact_add_rax_rdi_exact', 'add', 'rax, rdi', '4801f8'),
  (1934, 'x86_64_exact_and_al_cl', 'asm_x86_exact_and_al_cl_exact', 'and', 'al, cl', '20c8'),
  (1935, 'x86_64_exact_and_eax_0x0f', 'asm_x86_exact_and_eax_0x0f_exact', 'and', 'eax, 0x0F', '83e00f'),
  (1936, 'x86_64_exact_and_eax_3', 'asm_x86_exact_and_eax_3_exact', 'and', 'eax, 3', '83e003'),
  (1937, 'x86_64_exact_cmp_al_digit_9', 'asm_x86_exact_cmp_al_digit_9_exact', 'cmp', 'al, ''9''', '3c39'),
  (1938, 'x86_64_exact_cmp_al_A', 'asm_x86_exact_cmp_al_A_exact', 'cmp', 'al, ''A''', '3c41'),
  (1939, 'x86_64_exact_cmp_ebx_r14d', 'asm_x86_exact_cmp_ebx_r14d_exact', 'cmp', 'ebx, r14d', '4439f3'),
  (1940, 'x86_64_exact_cmp_r13_r14', 'asm_x86_exact_cmp_r13_r14_exact', 'cmp', 'r13, r14', '4d39f5'),
  (1941, 'x86_64_exact_cmp_r15d_r13d', 'asm_x86_exact_cmp_r15d_r13d_exact', 'cmp', 'r15d, r13d', '4539ef'),
  (1942, 'x86_64_exact_cmp_r8d_esi', 'asm_x86_exact_cmp_r8d_esi_exact', 'cmp', 'r8d, esi', '4139f0'),
  (1943, 'x86_64_exact_cmp_rax_2', 'asm_x86_exact_cmp_rax_2_exact', 'cmp', 'rax, 2', '4883f802'),
  (1944, 'x86_64_exact_div_ebx', 'asm_x86_exact_div_ebx_exact', 'div', 'ebx', 'f7f3'),
  (1945, 'x86_64_exact_idiv_ecx', 'asm_x86_exact_idiv_ecx_exact', 'idiv', 'ecx', 'f7f9'),
  (1946, 'x86_64_exact_inc_dword_ptr_rsp', 'asm_x86_exact_inc_dword_ptr_rsp_exact', 'inc', 'dword [rsp]', 'ff0424'),
  (1947, 'x86_64_exact_inc_r14', 'asm_x86_exact_inc_r14_exact', 'inc', 'r14', '49ffc6'),
  (1948, 'x86_64_exact_lea_rdi_ptr_rsp_160', 'asm_x86_exact_lea_rdi_ptr_rsp_160_exact', 'lea', 'rdi, [rsp + 160]', '488dbc24a0000000'),
  (1949, 'x86_64_exact_mov_ptr_r14_eax', 'asm_x86_exact_mov_ptr_r14_eax_exact', 'mov', '[r14], eax', '418906'),
  (1950, 'x86_64_exact_mov_ptr_rbp_72_rax', 'asm_x86_exact_mov_ptr_rbp_72_rax_exact', 'mov', '[rbp - 72], rax', '488945b8'),
  (1951, 'x86_64_exact_mov_eax_0', 'asm_x86_exact_mov_eax_0_exact', 'mov', 'eax, 0', 'b800000000'),
  (1952, 'x86_64_exact_mov_eax_8', 'asm_x86_exact_mov_eax_8_exact', 'mov', 'eax, 8', 'b808000000'),
  (1962, 'x86_64_exact_push_255', 'asm_x86_exact_push_255_exact', 'push', '255', '68ff000000'),
  (1963, 'x86_64_exact_push_128', 'asm_x86_exact_push_128_exact', 'push', '128', '6880000000'),
  (1964, 'x86_64_exact_add_r13d_eax', 'asm_x86_exact_add_r13d_eax_exact', 'add', 'r13d, eax', '4101c5'),
  (1965, 'x86_64_exact_add_r8d_eax', 'asm_x86_exact_add_r8d_eax_exact', 'add', 'r8d, eax', '4101c0'),
  (1966, 'x86_64_exact_mov_r13d_ebx', 'asm_x86_exact_mov_r13d_ebx_exact', 'mov', 'r13d, ebx', '4189dd'),
  (1967, 'x86_64_exact_cmp_ecx_2', 'asm_x86_exact_cmp_ecx_2_exact', 'cmp', 'ecx, 2', '83f902'),
  (1968, 'x86_64_exact_mov_rdx_ptr_rsp_8', 'asm_x86_exact_mov_rdx_ptr_rsp_8_exact', 'mov', 'rdx, [rsp + 8]', '488b542408'),
  (1969, 'x86_64_exact_add_rdi_r10', 'asm_x86_exact_add_rdi_r10_exact', 'add', 'rdi, r10', '4c01d7'),
  (1970, 'x86_64_exact_cmp_esi_2', 'asm_x86_exact_cmp_esi_2_exact', 'cmp', 'esi, 2', '83fe02'),
  (1971, 'x86_64_exact_sub_ecx_r13d', 'asm_x86_exact_sub_ecx_r13d_exact', 'sub', 'ecx, r13d', '4429e9'),
  (1972, 'x86_64_exact_cmp_esi_1', 'asm_x86_exact_cmp_esi_1_exact', 'cmp', 'esi, 1', '83fe01'),
  (1973, 'x86_64_exact_shr_ecx_2', 'asm_x86_exact_shr_ecx_2_exact', 'shr', 'ecx, 2', 'c1e902'),
  (1974, 'x86_64_exact_add_eax_2', 'asm_x86_exact_add_eax_2_exact', 'add', 'eax, 2', '83c002'),
  (1975, 'x86_64_exact_mov_ecx_100', 'asm_x86_exact_mov_ecx_100_exact', 'mov', 'ecx, 100', 'b964000000'),
  (1976, 'x86_64_exact_sub_eax_r10d', 'asm_x86_exact_sub_eax_r10d_exact', 'sub', 'eax, r10d', '4429d0'),
  (1977, 'x86_64_exact_mov_edi_ptr_rsp_32', 'asm_x86_exact_mov_edi_ptr_rsp_32_exact', 'mov', 'edi, [rsp + 32]', '8b7c2420'),
  (1978, 'x86_64_exact_inc_dword_ptr_rsp_44', 'asm_x86_exact_inc_dword_ptr_rsp_44_exact', 'inc', 'dword [rsp + 44]', 'ff44242c'),
  (1979, 'x86_64_exact_mov_ptr_rsp_24_eax', 'asm_x86_exact_mov_ptr_rsp_24_eax_exact', 'mov', '[rsp + 24], eax', '89442418'),
  (1980, 'x86_64_exact_mov_ptr_rsp_32_eax', 'asm_x86_exact_mov_ptr_rsp_32_eax_exact', 'mov', '[rsp + 32], eax', '89442420'),
  (1981, 'x86_64_exact_mov_ptr_rsp_36_eax', 'asm_x86_exact_mov_ptr_rsp_36_eax_exact', 'mov', '[rsp + 36], eax', '89442424'),
  (1982, 'x86_64_exact_mov_eax_ptr_rsp_88', 'asm_x86_exact_mov_eax_ptr_rsp_88_exact', 'mov', 'eax, [rsp + 88]', '8b442458'),
  (1983, 'x86_64_exact_mov_eax_ptr_rsp_96', 'asm_x86_exact_mov_eax_ptr_rsp_96_exact', 'mov', 'eax, [rsp + 96]', '8b442460'),
  (1984, 'x86_64_exact_imul_rax_rcx', 'asm_x86_exact_imul_rax_rcx_exact', 'imul', 'rax, rcx', '480fafc1'),
  (1985, 'x86_64_exact_mov_ptr_rsp_40_eax', 'asm_x86_exact_mov_ptr_rsp_40_eax_exact', 'mov', '[rsp + 40], eax', '89442428'),
  (1986, 'x86_64_exact_mov_eax_ptr_rsp_72', 'asm_x86_exact_mov_eax_ptr_rsp_72_exact', 'mov', 'eax, [rsp + 72]', '8b442448'),
  (1987, 'x86_64_exact_mov_esi_ptr_rsp_36', 'asm_x86_exact_mov_esi_ptr_rsp_36_exact', 'mov', 'esi, [rsp + 36]', '8b742424'),
  (1988, 'x86_64_exact_mov_r11d_4', 'asm_x86_exact_mov_r11d_4_exact', 'mov', 'r11d, 4', '41bb04000000'),
  (1989, 'x86_64_exact_movzx_edx_dl', 'asm_x86_exact_movzx_edx_dl_exact', 'movzx', 'edx, dl', '0fb6d2'),
  (1990, 'x86_64_exact_imul_eax_edx', 'asm_x86_exact_imul_eax_edx_exact', 'imul', 'eax, edx', '0fafc2'),
  (1991, 'x86_64_exact_mov_ptr_r13_rcx_al', 'asm_x86_exact_mov_ptr_r13_rcx_al_exact', 'mov', '[r13 + rcx], al', '4188440d00'),
  (1992, 'x86_64_exact_mov_eax_ptr_rsp_48', 'asm_x86_exact_mov_eax_ptr_rsp_48_exact', 'mov', 'eax, [rsp + 48]', '8b442430'),
  (1993, 'x86_64_exact_mov_eax_ptr_rsp_64', 'asm_x86_exact_mov_eax_ptr_rsp_64_exact', 'mov', 'eax, [rsp + 64]', '8b442440'),
  (1994, 'x86_64_exact_add_eax_ptr_rsp_4', 'asm_x86_exact_add_eax_ptr_rsp_4_exact', 'add', 'eax, [rsp + 4]', '03442404'),
  (1995, 'x86_64_exact_cmp_r11d_eax', 'asm_x86_exact_cmp_r11d_eax_exact', 'cmp', 'r11d, eax', '4139c3'),
  (1996, 'x86_64_exact_cmp_r8d_4', 'asm_x86_exact_cmp_r8d_4_exact', 'cmp', 'r8d, 4', '4183f804'),
  (1997, 'x86_64_exact_mov_ptr_rsp_44_eax', 'asm_x86_exact_mov_ptr_rsp_44_eax_exact', 'mov', '[rsp + 44], eax', '8944242c'),
  (1998, 'x86_64_exact_mov_ptr_rsp_48_eax', 'asm_x86_exact_mov_ptr_rsp_48_eax_exact', 'mov', '[rsp + 48], eax', '89442430'),
  (1999, 'x86_64_exact_mov_ptr_rsp_68_ecx', 'asm_x86_exact_mov_ptr_rsp_68_ecx_exact', 'mov', '[rsp + 68], ecx', '894c2444'),
  (2000, 'x86_64_exact_mov_ptr_rsp_8_rcx', 'asm_x86_exact_mov_ptr_rsp_8_rcx_exact', 'mov', '[rsp + 8], rcx', '48894c2408'),
  (2001, 'x86_64_exact_mov_dword_ptr_rsp_72_0', 'asm_x86_exact_mov_dword_ptr_rsp_72_0_exact', 'mov', 'dword [rsp + 72], 0', 'c744244800000000'),
  (2002, 'x86_64_exact_mov_ebx_r9d', 'asm_x86_exact_mov_ebx_r9d_exact', 'mov', 'ebx, r9d', '4489cb'),
  (2003, 'x86_64_exact_mov_ecx_ptr_rsp_64', 'asm_x86_exact_mov_ecx_ptr_rsp_64_exact', 'mov', 'ecx, [rsp + 64]', '8b4c2440'),
  (2004, 'x86_64_exact_add_eax_6', 'asm_x86_exact_add_eax_6_exact', 'add', 'eax, 6', '83c006'),
  (2005, 'x86_64_exact_cmp_edi_255', 'asm_x86_exact_cmp_edi_255_exact', 'cmp', 'edi, 255', '81ffff000000'),
  (2006, 'x86_64_exact_cmp_r8d_2', 'asm_x86_exact_cmp_r8d_2_exact', 'cmp', 'r8d, 2', '4183f802'),
  (2007, 'x86_64_exact_inc_dword_ptr_rsp_60', 'asm_x86_exact_inc_dword_ptr_rsp_60_exact', 'inc', 'dword [rsp + 60]', 'ff44243c'),
  (2008, 'x86_64_exact_inc_dword_ptr_rsp_72', 'asm_x86_exact_inc_dword_ptr_rsp_72_exact', 'inc', 'dword [rsp + 72]', 'ff442448'),
  (2009, 'x86_64_exact_mov_ptr_rsp_16_r9', 'asm_x86_exact_mov_ptr_rsp_16_r9_exact', 'mov', '[rsp + 16], r9', '4c894c2410'),
  (2010, 'x86_64_exact_mov_ptr_rsp_32_edx', 'asm_x86_exact_mov_ptr_rsp_32_edx_exact', 'mov', '[rsp + 32], edx', '89542420'),
  (2011, 'x86_64_exact_mov_ptr_rsp_36_ecx', 'asm_x86_exact_mov_ptr_rsp_36_ecx_exact', 'mov', '[rsp + 36], ecx', '894c2424'),
  (2012, 'x86_64_exact_mov_dword_ptr_rsp_60_0', 'asm_x86_exact_mov_dword_ptr_rsp_60_0_exact', 'mov', 'dword [rsp + 60], 0', 'c744243c00000000'),
  (2013, 'x86_64_exact_mov_eax_ptr_rsp_60', 'asm_x86_exact_mov_eax_ptr_rsp_60_exact', 'mov', 'eax, [rsp + 60]', '8b44243c'),
  (2014, 'x86_64_exact_movzx_eax_byte_ptr_r11_rcx', 'asm_x86_exact_movzx_eax_byte_ptr_r11_rcx_exact', 'movzx', 'eax, byte [r11 + rcx]', '410fb6040b'),
  (2015, 'x86_64_exact_movzx_edx_byte_ptr_r12_1', 'asm_x86_exact_movzx_edx_byte_ptr_r12_1_exact', 'movzx', 'edx, byte [r12 + 1]', '410fb6542401'),
  (2016, 'x86_64_exact_mov_r14_r13', 'asm_x86_exact_mov_r14_r13_exact', 'mov', 'r14, r13', '4d89ee'),
  (2017, 'x86_64_exact_mov_r9d_r15d', 'asm_x86_exact_mov_r9d_r15d_exact', 'mov', 'r9d, r15d', '4589f9'),
  (2018, 'x86_64_exact_cmp_esi_0', 'asm_x86_exact_cmp_esi_0_exact', 'cmp', 'esi, 0', '83fe00'),
  (2019, 'x86_64_exact_add_eax_r10d', 'asm_x86_exact_add_eax_r10d_exact', 'add', 'eax, r10d', '4401d0'),
  (2020, 'x86_64_exact_lea_r11_ptr_r13_rax', 'asm_x86_exact_lea_r11_ptr_r13_rax_exact', 'lea', 'r11, [r13 + rax]', '4d8d5c0500'),
  (2021, 'x86_64_exact_sub_eax_r9d', 'asm_x86_exact_sub_eax_r9d_exact', 'sub', 'eax, r9d', '4429c8'),
  (2022, 'x86_64_exact_cmp_eax_16', 'asm_x86_exact_cmp_eax_16_exact', 'cmp', 'eax, 16', '83f810'),
  (2023, 'x86_64_exact_cmp_r14d_4', 'asm_x86_exact_cmp_r14d_4_exact', 'cmp', 'r14d, 4', '4183fe04'),
  (2024, 'x86_64_exact_movzx_edi_byte_ptr_r12', 'asm_x86_exact_movzx_edi_byte_ptr_r12_exact', 'movzx', 'edi, byte [r12]', '410fb63c24'),
  (2025, 'x86_64_exact_add_eax_ptr_rsp_8', 'asm_x86_exact_add_eax_ptr_rsp_8_exact', 'add', 'eax, [rsp + 8]', '03442408'),
  (2026, 'x86_64_exact_mov_r8d_ecx', 'asm_x86_exact_mov_r8d_ecx_exact', 'mov', 'r8d, ecx', '4189c8'),
  (2027, 'x86_64_exact_mov_ptr_rsp_16_eax', 'asm_x86_exact_mov_ptr_rsp_16_eax_exact', 'mov', '[rsp + 16], eax', '89442410'),
  (2028, 'x86_64_exact_mov_rsi_ptr_rsp_8', 'asm_x86_exact_mov_rsi_ptr_rsp_8_exact', 'mov', 'rsi, [rsp + 8]', '488b742408'),
  (2029, 'x86_64_exact_cmp_edx_1', 'asm_x86_exact_cmp_edx_1_exact', 'cmp', 'edx, 1', '83fa01'),
  (2030, 'x86_64_exact_mov_ptr_rdi_2_al', 'asm_x86_exact_mov_ptr_rdi_2_al_exact', 'mov', '[rdi + 2], al', '884702'),
  (2031, 'x86_64_exact_movzx_edx_byte_ptr_r12_rcx', 'asm_x86_exact_movzx_edx_byte_ptr_r12_rcx_exact', 'movzx', 'edx, byte [r12 + rcx]', '410fb6140c'),
  (2032, 'x86_64_exact_shr_eax_2', 'asm_x86_exact_shr_eax_2_exact', 'shr', 'eax, 2', 'c1e802'),
  (2033, 'x86_64_exact_mov_ptr_rcx_al', 'asm_x86_exact_mov_ptr_rcx_al_exact', 'mov', '[rcx], al', '8801'),
  (2034, 'x86_64_exact_mov_ecx_edi', 'asm_x86_exact_mov_ecx_edi_exact', 'mov', 'ecx, edi', '89f9'),
  (2035, 'x86_64_exact_neg_ebx', 'asm_x86_exact_neg_ebx_exact', 'neg', 'ebx', 'f7db'),
  (2036, 'x86_64_exact_mov_ptr_r14_rbx_al', 'asm_x86_exact_mov_ptr_r14_rbx_al_exact', 'mov', '[r14 + rbx], al', '4188041e'),
  (2037, 'x86_64_exact_cmp_edx_ecx', 'asm_x86_exact_cmp_edx_ecx_exact', 'cmp', 'edx, ecx', '39ca'),
  (2038, 'x86_64_exact_mov_esi_ptr_rsp_32', 'asm_x86_exact_mov_esi_ptr_rsp_32_exact', 'mov', 'esi, [rsp + 32]', '8b742420'),
  (2039, 'x86_64_exact_lea_rsi_ptr_rsp_8', 'asm_x86_exact_lea_rsi_ptr_rsp_8_exact', 'lea', 'rsi, [rsp + 8]', '488d742408'),
  (2040, 'x86_64_exact_lea_rdx_ptr_rsp_16', 'asm_x86_exact_lea_rdx_ptr_rsp_16_exact', 'lea', 'rdx, [rsp + 16]', '488d542410'),
  (2041, 'x86_64_exact_movzx_edx_byte_ptr_rbx_rdx', 'asm_x86_exact_movzx_edx_byte_ptr_rbx_rdx_exact', 'movzx', 'edx, byte [rbx + rdx]', '0fb61413'),
  (2042, 'x86_64_exact_movzx_esi_byte_ptr_rbx', 'asm_x86_exact_movzx_esi_byte_ptr_rbx_exact', 'movzx', 'esi, byte [rbx]', '0fb633'),
  (2043, 'x86_64_exact_mov_eax_ptr_rax', 'asm_x86_exact_mov_eax_ptr_rax_exact', 'mov', 'eax, [rax]', '8b00'),
  (2044, 'x86_64_exact_mov_edx_ptr_rsp_16', 'asm_x86_exact_mov_edx_ptr_rsp_16_exact', 'mov', 'edx, [rsp + 16]', '8b542410'),
  (2045, 'x86_64_exact_mov_edx_ptr_rsp', 'asm_x86_exact_mov_edx_ptr_rsp_exact', 'mov', 'edx, [rsp]', '8b1424'),
  (2046, 'x86_64_exact_mov_ptr_r10_rdx_al', 'asm_x86_exact_mov_ptr_r10_rdx_al_exact', 'mov', '[r10 + rdx], al', '41880412'),
  (2047, 'x86_64_exact_inc_dword_ptr_rsp_8', 'asm_x86_exact_inc_dword_ptr_rsp_8_exact', 'inc', 'dword [rsp + 8]', 'ff442408'),
  (2048, 'x86_64_exact_mov_dword_ptr_rsp_8_0', 'asm_x86_exact_mov_dword_ptr_rsp_8_0_exact', 'mov', 'dword [rsp + 8], 0', 'c744240800000000'),
  (2049, 'x86_64_exact_movzx_edx_byte_ptr_r14_rbx', 'asm_x86_exact_movzx_edx_byte_ptr_r14_rbx_exact', 'movzx', 'edx, byte [r14 + rbx]', '410fb6141e'),
  (2050, 'x86_64_exact_sar_eax_1', 'asm_x86_exact_sar_eax_1_exact', 'sar', 'eax, 1', 'd1f8'),
  (2051, 'x86_64_exact_add_r10d_eax', 'asm_x86_exact_add_r10d_eax_exact', 'add', 'r10d, eax', '4101c2'),
  (2052, 'x86_64_exact_cmp_ecx_edx', 'asm_x86_exact_cmp_ecx_edx_exact', 'cmp', 'ecx, edx', '39d1'),
  (2053, 'x86_64_exact_mov_r9_r14', 'asm_x86_exact_mov_r9_r14_exact', 'mov', 'r9, r14', '4d89f1'),
  (2054, 'x86_64_exact_add_ecx_r14d', 'asm_x86_exact_add_ecx_r14d_exact', 'add', 'ecx, r14d', '4401f1'),
  (2055, 'x86_64_exact_mov_r10_ptr_rsp', 'asm_x86_exact_mov_r10_ptr_rsp_exact', 'mov', 'r10, [rsp]', '4c8b1424'),
  (2056, 'x86_64_exact_sub_edx_eax', 'asm_x86_exact_sub_edx_eax_exact', 'sub', 'edx, eax', '29c2'),
  (2057, 'x86_64_exact_or_ebx_eax', 'asm_x86_exact_or_ebx_eax_exact', 'or', 'ebx, eax', '09c3'),
  (2058, 'x86_64_exact_mov_rax_ptr_rsp_152', 'asm_x86_exact_mov_rax_ptr_rsp_152_exact', 'mov', 'rax, [rsp + 152]', '488b842498000000'),
  (2059, 'x86_64_exact_add_ecx_r11d', 'asm_x86_exact_add_ecx_r11d_exact', 'add', 'ecx, r11d', '4401d9'),
  (2060, 'x86_64_exact_shl_ecx_16', 'asm_x86_exact_shl_ecx_16_exact', 'shl', 'ecx, 16', 'c1e110'),
  (2061, 'x86_64_exact_mov_edi_esi', 'asm_x86_exact_mov_edi_esi_exact', 'mov', 'edi, esi', '89f7'),
  (2062, 'x86_64_exact_movzx_ecx_byte_ptr_rdi_2', 'asm_x86_exact_movzx_ecx_byte_ptr_rdi_2_exact', 'movzx', 'ecx, byte [rdi + 2]', '0fb64f02'),
  (2063, 'x86_64_exact_mul_esi', 'asm_x86_exact_mul_esi_exact', 'mul', 'esi', 'f7e6'),
  (2064, 'x86_64_exact_mov_r8d_r13d', 'asm_x86_exact_mov_r8d_r13d_exact', 'mov', 'r8d, r13d', '4589e8'),
  (2065, 'x86_64_exact_mov_ptr_rdx_eax', 'asm_x86_exact_mov_ptr_rdx_eax_exact', 'mov', '[rdx], eax', '8902'),
  (2066, 'x86_64_exact_sub_eax_r11d', 'asm_x86_exact_sub_eax_r11d_exact', 'sub', 'eax, r11d', '4429d8'),
  (2067, 'x86_64_exact_mov_rax_ptr_rsp_8', 'asm_x86_exact_mov_rax_ptr_rsp_8_exact', 'mov', 'rax, [rsp + 8]', '488b442408'),
  (2068, 'x86_64_exact_cmp_al_lower_z', 'asm_x86_exact_cmp_al_lower_z_exact', 'cmp', 'al, ''z''', '3c7a'),
  (2069, 'x86_64_exact_mov_ecx_ptr_rsp', 'asm_x86_exact_mov_ecx_ptr_rsp_exact', 'mov', 'ecx, [rsp]', '8b0c24'),
  (2070, 'x86_64_exact_mov_ptr_rsp_esi', 'asm_x86_exact_mov_ptr_rsp_esi_exact', 'mov', '[rsp], esi', '893424'),
  (2071, 'x86_64_exact_add_edx_r9d', 'asm_x86_exact_add_edx_r9d_exact', 'add', 'edx, r9d', '4401ca'),
  (2072, 'x86_64_exact_mov_eax_5', 'asm_x86_exact_mov_eax_5_exact', 'mov', 'eax, 5', 'b805000000'),
  (2073, 'x86_64_exact_mov_r8d_3', 'asm_x86_exact_mov_r8d_3_exact', 'mov', 'r8d, 3', '41b803000000'),
  (2074, 'x86_64_exact_cmp_eax_r15d', 'asm_x86_exact_cmp_eax_r15d_exact', 'cmp', 'eax, r15d', '4439f8'),
  (2075, 'x86_64_exact_movzx_eax_byte_ptr_r8', 'asm_x86_exact_movzx_eax_byte_ptr_r8_exact', 'movzx', 'eax, byte [r8]', '410fb600'),
  (2076, 'x86_64_exact_cmp_al_upper_z', 'asm_x86_exact_cmp_al_upper_z_exact', 'cmp', 'al, ''Z''', '3c5a'),
  (2077, 'x86_64_exact_mov_r14d_r8d', 'asm_x86_exact_mov_r14d_r8d_exact', 'mov', 'r14d, r8d', '4589c6'),
  (2078, 'x86_64_exact_mov_ptr_rsp_al', 'asm_x86_exact_mov_ptr_rsp_al_exact', 'mov', '[rsp], al', '880424'),
  (2079, 'x86_64_exact_xor_edx_1', 'asm_x86_exact_xor_edx_1_exact', 'xor', 'edx, 1', '83f201'),
  (2080, 'x86_64_exact_cmp_edi_3', 'asm_x86_exact_cmp_edi_3_exact', 'cmp', 'edi, 3', '83ff03'),
  (2081, 'x86_64_exact_test_r10_r10', 'asm_x86_exact_test_r10_r10_exact', 'test', 'r10, r10', '4d85d2'),
  (2082, 'x86_64_exact_mov_r9_ptr_rsp_32', 'asm_x86_exact_mov_r9_ptr_rsp_32_exact', 'mov', 'r9, [rsp + 32]', '4c8b4c2420'),
  (2083, 'x86_64_exact_mov_eax_ptr_rsp_40', 'asm_x86_exact_mov_eax_ptr_rsp_40_exact', 'mov', 'eax, [rsp + 40]', '8b442428'),
  (2084, 'x86_64_exact_mov_r8d_r14d', 'asm_x86_exact_mov_r8d_r14d_exact', 'mov', 'r8d, r14d', '4589f0'),
  (2085, 'x86_64_exact_add_edx_r14d', 'asm_x86_exact_add_edx_r14d_exact', 'add', 'edx, r14d', '4401f2'),
  (2086, 'x86_64_exact_add_ecx_r10d', 'asm_x86_exact_add_ecx_r10d_exact', 'add', 'ecx, r10d', '4401d1'),
  (2087, 'x86_64_exact_lea_rdi_ptr_r15_rax', 'asm_x86_exact_lea_rdi_ptr_r15_rax_exact', 'lea', 'rdi, [r15 + rax]', '498d3c07'),
  (2088, 'x86_64_exact_mov_ptr_rsp_rdx', 'asm_x86_exact_mov_ptr_rsp_rdx_exact', 'mov', '[rsp], rdx', '48891424'),
  (2089, 'x86_64_exact_add_edx_r10d', 'asm_x86_exact_add_edx_r10d_exact', 'add', 'edx, r10d', '4401d2'),
  (2090, 'x86_64_exact_or_eax_r15d', 'asm_x86_exact_or_eax_r15d_exact', 'or', 'eax, r15d', '4409f8'),
  (2091, 'x86_64_exact_mov_rax_ptr_rsp_72', 'asm_x86_exact_mov_rax_ptr_rsp_72_exact', 'mov', 'rax, [rsp + 72]', '488b442448'),
  (2092, 'x86_64_exact_lea_rdx_ptr_rsp_8', 'asm_x86_exact_lea_rdx_ptr_rsp_8_exact', 'lea', 'rdx, [rsp + 8]', '488d542408'),
  (2093, 'x86_64_exact_mov_ptr_rsp_8_r9', 'asm_x86_exact_mov_ptr_rsp_8_r9_exact', 'mov', '[rsp + 8], r9', '4c894c2408'),
  (2094, 'x86_64_exact_mov_dword_ptr_rsp_28_0', 'asm_x86_exact_mov_dword_ptr_rsp_28_0_exact', 'mov', 'dword [rsp + 28], 0', 'c744241c00000000'),
  (2095, 'x86_64_exact_mov_ptr_rsp_r8', 'asm_x86_exact_mov_ptr_rsp_r8_exact', 'mov', '[rsp], r8', '4c890424'),
  (2096, 'x86_64_exact_mov_edx_ptr_rsp_28', 'asm_x86_exact_mov_edx_ptr_rsp_28_exact', 'mov', 'edx, [rsp + 28]', '8b54241c'),
  (2097, 'x86_64_exact_add_r9_r14', 'asm_x86_exact_add_r9_r14_exact', 'add', 'r9, r14', '4d01f1'),
  (2098, 'x86_64_exact_mov_ptr_rsp_12_ecx', 'asm_x86_exact_mov_ptr_rsp_12_ecx_exact', 'mov', '[rsp + 12], ecx', '894c240c'),
  (2099, 'x86_64_exact_mov_ptr_rsp_4_ecx', 'asm_x86_exact_mov_ptr_rsp_4_ecx_exact', 'mov', '[rsp + 4], ecx', '894c2404'),
  (2100, 'x86_64_exact_mov_ptr_rsp_8_ecx', 'asm_x86_exact_mov_ptr_rsp_8_ecx_exact', 'mov', '[rsp + 8], ecx', '894c2408'),
  (2101, 'x86_64_exact_mov_rax_ptr_rsp_104', 'asm_x86_exact_mov_rax_ptr_rsp_104_exact', 'mov', 'rax, [rsp + 104]', '488b442468'),
  (2102, 'x86_64_exact_mov_rax_ptr_rsp_96', 'asm_x86_exact_mov_rax_ptr_rsp_96_exact', 'mov', 'rax, [rsp + 96]', '488b442460'),
  (2103, 'x86_64_exact_mov_ptr_r15_rcx_4_eax', 'asm_x86_exact_mov_ptr_r15_rcx_4_eax_exact', 'mov', '[r15 + rcx * 4], eax', '4189048f'),
  (2104, 'x86_64_exact_mov_ecx_ptr_rsp_12', 'asm_x86_exact_mov_ecx_ptr_rsp_12_exact', 'mov', 'ecx, [rsp + 12]', '8b4c240c'),
  (2105, 'x86_64_exact_mov_ecx_ptr_rsp_20', 'asm_x86_exact_mov_ecx_ptr_rsp_20_exact', 'mov', 'ecx, [rsp + 20]', '8b4c2414'),
  (2106, 'x86_64_exact_mov_rax_ptr_rsp_80', 'asm_x86_exact_mov_rax_ptr_rsp_80_exact', 'mov', 'rax, [rsp + 80]', '488b442450'),
  (2107, 'x86_64_exact_mov_rax_ptr_rsp_88', 'asm_x86_exact_mov_rax_ptr_rsp_88_exact', 'mov', 'rax, [rsp + 88]', '488b442458'),
  (2108, 'x86_64_exact_mov_ptr_rsp_96_rax', 'asm_x86_exact_mov_ptr_rsp_96_rax_exact', 'mov', '[rsp + 96], rax', '4889442460'),
  (2109, 'x86_64_exact_mov_ptr_rsp_1_al', 'asm_x86_exact_mov_ptr_rsp_1_al_exact', 'mov', '[rsp + 1], al', '88442401'),
  (2110, 'x86_64_exact_mov_ptr_rsp_2_al', 'asm_x86_exact_mov_ptr_rsp_2_al_exact', 'mov', '[rsp + 2], al', '88442402'),
  (2111, 'x86_64_exact_mov_ptr_rsp_3_al', 'asm_x86_exact_mov_ptr_rsp_3_al_exact', 'mov', '[rsp + 3], al', '88442403'),
  (2112, 'x86_64_exact_mov_rdx_rbp', 'asm_x86_exact_mov_rdx_rbp_exact', 'mov', 'rdx, rbp', '4889ea'),
  (2113, 'x86_64_exact_mov_eax_rsp_12', 'asm_x86_exact_mov_eax_rsp_12_exact', 'mov', 'eax, [rsp + 12]', '8b44240c'),
  (2114, 'x86_64_exact_cmp_eax_rsp_8', 'asm_x86_exact_cmp_eax_rsp_8_exact', 'cmp', 'eax, [rsp + 8]', '3b442408'),
  (2115, 'x86_64_exact_mov_r9d_r8d', 'asm_x86_exact_mov_r9d_r8d_exact', 'mov', 'r9d, r8d', '4589c1'),
  (2116, 'x86_64_exact_shl_ebx_1', 'asm_x86_exact_shl_ebx_1_exact', 'shl', 'ebx, 1', 'd1e3'),
  (2117, 'x86_64_exact_shl_edx_3', 'asm_x86_exact_shl_edx_3_exact', 'shl', 'edx, 3', 'c1e203'),
  (2118, 'x86_64_exact_sub_eax_rsp_8', 'asm_x86_exact_sub_eax_rsp_8_exact', 'sub', 'eax, [rsp + 8]', '2b442408'),
  (2119, 'x86_64_exact_sub_r8d_eax', 'asm_x86_exact_sub_r8d_eax_exact', 'sub', 'r8d, eax', '4129c0'),
  (2120, 'x86_64_exact_mov_rsp_rsi', 'asm_x86_exact_mov_rsp_rsi_exact', 'mov', '[rsp], rsi', '48893424'),
  (2121, 'x86_64_exact_sub_ecx_r14d', 'asm_x86_exact_sub_ecx_r14d_exact', 'sub', 'ecx, r14d', '4429f1'),
  (2122, 'x86_64_exact_add_edx_r8d', 'asm_x86_exact_add_edx_r8d_exact', 'add', 'edx, r8d', '4401c2'),
  (2123, 'x86_64_exact_imul_ecx_r13d', 'asm_x86_exact_imul_ecx_r13d_exact', 'imul', 'ecx, r13d', '410fafcd'),
  (2124, 'x86_64_exact_add_r8d_r10d', 'asm_x86_exact_add_r8d_r10d_exact', 'add', 'r8d, r10d', '4501d0'),
  (2125, 'x86_64_exact_sub_r10d_r9d', 'asm_x86_exact_sub_r10d_r9d_exact', 'sub', 'r10d, r9d', '4529ca'),
  (2126, 'x86_64_exact_movzx_eax_byte_rsi_1', 'asm_x86_exact_movzx_eax_byte_rsi_1_exact', 'movzx', 'eax, byte [rsi + 1]', '0fb64601'),
  (2127, 'x86_64_exact_movzx_eax_byte_rsi_2', 'asm_x86_exact_movzx_eax_byte_rsi_2_exact', 'movzx', 'eax, byte [rsi + 2]', '0fb64602'),
  (2128, 'x86_64_exact_movzx_eax_byte_rsi_3', 'asm_x86_exact_movzx_eax_byte_rsi_3_exact', 'movzx', 'eax, byte [rsi + 3]', '0fb64603'),
  (2129, 'x86_64_exact_movzx_eax_byte_r12_3', 'asm_x86_exact_movzx_eax_byte_r12_3_exact', 'movzx', 'eax, byte [r12 + 3]', '410fb6442403'),
  (2130, 'x86_64_exact_cmp_eax_64', 'asm_x86_exact_cmp_eax_64_exact', 'cmp', 'eax, 64', '83f840'),
  (2131, 'x86_64_exact_movzx_edi_byte_r12_rbx', 'asm_x86_exact_movzx_edi_byte_r12_rbx_exact', 'movzx', 'edi, byte [r12 + rbx]', '410fb63c1c'),
  (2132, 'x86_64_exact_cmp_al_rsi', 'asm_x86_exact_cmp_al_rsi_exact', 'cmp', 'al, [rsi]', '3a06'),
  (2133, 'x86_64_exact_add_r9d_ecx', 'asm_x86_exact_add_r9d_ecx_exact', 'add', 'r9d, ecx', '4101c9'),
  (2134, 'x86_64_exact_movzx_edi_byte_r12_r10', 'asm_x86_exact_movzx_edi_byte_r12_r10_exact', 'movzx', 'edi, byte [r12 + r10]', '430fb63c14'),
  (2135, 'x86_64_exact_cmp_eax_15', 'asm_x86_exact_cmp_eax_15_exact', 'cmp', 'eax, 15', '83f80f'),
  (2136, 'x86_64_exact_mov_r8d_rsp', 'asm_x86_exact_mov_r8d_rsp_exact', 'mov', 'r8d, [rsp]', '448b0424'),
  (2137, 'x86_64_exact_cmp_ecx_r13d', 'asm_x86_exact_cmp_ecx_r13d_exact', 'cmp', 'ecx, r13d', '4439e9'),
  (2138, 'x86_64_exact_cmp_r8d_edx', 'asm_x86_exact_cmp_r8d_edx_exact', 'cmp', 'r8d, edx', '4139d0'),
  (2139, 'x86_64_exact_movzx_ebx_sil', 'asm_x86_exact_movzx_ebx_sil_exact', 'movzx', 'ebx, sil', '400fb6de'),
  (2140, 'x86_64_exact_add_edx_r15d', 'asm_x86_exact_add_edx_r15d_exact', 'add', 'edx, r15d', '4401fa'),
  (2141, 'x86_64_exact_mov_r11d_r10d', 'asm_x86_exact_mov_r11d_r10d_exact', 'mov', 'r11d, r10d', '4589d3'),
  (2142, 'x86_64_exact_movzx_eax_byte_rdi_1', 'asm_x86_exact_movzx_eax_byte_rdi_1_exact', 'movzx', 'eax, byte [rdi + 1]', '0fb64701'),
  (2143, 'x86_64_exact_movzx_eax_byte_rdi_2', 'asm_x86_exact_movzx_eax_byte_rdi_2_exact', 'movzx', 'eax, byte [rdi + 2]', '0fb64702'),
  (2144, 'x86_64_exact_movzx_eax_byte_rdi_3', 'asm_x86_exact_movzx_eax_byte_rdi_3_exact', 'movzx', 'eax, byte [rdi + 3]', '0fb64703'),
  (2145, 'x86_64_exact_test_ecx_1', 'asm_x86_exact_test_ecx_1_exact', 'test', 'ecx, 1', 'f7c101000000'),
  (2146, 'x86_64_exact_mov_esi_rsp_4', 'asm_x86_exact_mov_esi_rsp_4_exact', 'mov', 'esi, [rsp + 4]', '8b742404'),
  (2147, 'x86_64_exact_shr_r8d_2', 'asm_x86_exact_shr_r8d_2_exact', 'shr', 'r8d, 2', '41c1e802'),
  (2148, 'x86_64_exact_cmp_ecx_rsp', 'asm_x86_exact_cmp_ecx_rsp_exact', 'cmp', 'ecx, [rsp]', '3b0c24'),
  (2149, 'x86_64_exact_mov_r15_r14', 'asm_x86_exact_mov_r15_r14_exact', 'mov', 'r15, r14', '4d89f7'),
  (2150, 'x86_64_exact_mov_dword_rsp_20_0', 'asm_x86_exact_mov_dword_rsp_20_0_exact', 'mov', 'dword [rsp + 20], 0', 'c744241400000000'),
  (2151, 'x86_64_exact_mov_r12_rbx_al', 'asm_x86_exact_mov_r12_rbx_al_exact', 'mov', '[r12 + rbx], al', '4188041c'),
  (2152, 'x86_64_exact_mul_r12d', 'asm_x86_exact_mul_r12d_exact', 'mul', 'r12d', '41f7e4'),
  (2153, 'x86_64_exact_xor_rdi_rdi', 'asm_x86_exact_xor_rdi_rdi_exact', 'xor', 'rdi, rdi', '4831ff'),
  (2154, 'x86_64_exact_mov_r14_r9', 'asm_x86_exact_mov_r14_r9_exact', 'mov', 'r14, r9', '4d89ce'),
  (2155, 'x86_64_exact_mov_r14_rdi', 'asm_x86_exact_mov_r14_rdi_exact', 'mov', 'r14, rdi', '4989fe'),
  (2156, 'x86_64_exact_mov_r9_rbp_48', 'asm_x86_exact_mov_r9_rbp_48_exact', 'mov', 'r9, [rbp - 48]', '4c8b4dd0'),
  (2157, 'x86_64_exact_mov_ecx_rsp_48', 'asm_x86_exact_mov_ecx_rsp_48_exact', 'mov', 'ecx, [rsp + 48]', '8b4c2430'),
  (2158, 'x86_64_exact_mov_edi_rsp_24', 'asm_x86_exact_mov_edi_rsp_24_exact', 'mov', 'edi, [rsp + 24]', '8b7c2418'),
  (2159, 'x86_64_exact_mov_esi_rsp_12', 'asm_x86_exact_mov_esi_rsp_12_exact', 'mov', 'esi, [rsp + 12]', '8b74240c'),
  (2160, 'x86_64_exact_mov_r8d_rsp_44', 'asm_x86_exact_mov_r8d_rsp_44_exact', 'mov', 'r8d, [rsp + 44]', '448b44242c'),
  (2161, 'x86_64_exact_mov_r8d_rsp_52', 'asm_x86_exact_mov_r8d_rsp_52_exact', 'mov', 'r8d, [rsp + 52]', '448b442434'),
  (2162, 'x86_64_exact_mov_rsp_r9d', 'asm_x86_exact_mov_rsp_r9d_exact', 'mov', '[rsp], r9d', '44890c24'),
  (2164, 'x86_64_exact_mov_r11_r9', 'asm_x86_exact_mov_r11_r9_exact', 'mov', 'r11, r9', '4d89cb'),
  (2165, 'x86_64_exact_mov_edi_rsp_28', 'asm_x86_exact_mov_edi_rsp_28_exact', 'mov', 'edi, [rsp + 28]', '8b7c241c'),
  (2166, 'x86_64_exact_movzx_eax_byte_r12_rsi', 'asm_x86_exact_movzx_eax_byte_r12_rsi_exact', 'movzx', 'eax, byte [r12 + rsi]', '410fb60434'),
  (2167, 'x86_64_exact_mov_rsp_20_eax', 'asm_x86_exact_mov_rsp_20_eax_exact', 'mov', '[rsp + 20], eax', '89442414'),
  (2168, 'x86_64_exact_add_r8d_edx', 'asm_x86_exact_add_r8d_edx_exact', 'add', 'r8d, edx', '4101d0'),
  (2169, 'x86_64_exact_lea_edi_rax_rax2', 'asm_x86_exact_lea_edi_rax_rax2_exact', 'lea', 'edi, [rax + rax * 2]', '8d3c40'),
  (2170, 'x86_64_exact_add_eax_rsp_12', 'asm_x86_exact_add_eax_rsp_12_exact', 'add', 'eax, [rsp + 12]', '0344240c'),
  (2171, 'x86_64_exact_lea_eax_rax2', 'asm_x86_exact_lea_eax_rax2_exact', 'lea', 'eax, [rax * 2]', '8d0400'),
  (2172, 'x86_64_exact_lea_r10_r11_rax', 'asm_x86_exact_lea_r10_r11_rax_exact', 'lea', 'r10, [r11 + rax]', '4d8d1403'),
  (2173, 'x86_64_exact_lea_r11_r10_rax', 'asm_x86_exact_lea_r11_r10_rax_exact', 'lea', 'r11, [r10 + rax]', '4d8d1c02'),
  (2174, 'x86_64_exact_mov_r13_rdx_al', 'asm_x86_exact_mov_r13_rdx_al_exact', 'mov', '[r13 + rdx], al', '4188441500'),
  (2175, 'x86_64_exact_mov_rsp_8_r9d', 'asm_x86_exact_mov_rsp_8_r9d_exact', 'mov', '[rsp + 8], r9d', '44894c2408'),
  (2176, 'x86_64_exact_mov_rsp_edx', 'asm_x86_exact_mov_rsp_edx_exact', 'mov', '[rsp], edx', '891424'),
  (2177, 'x86_64_exact_mov_edi_rsp_16', 'asm_x86_exact_mov_edi_rsp_16_exact', 'mov', 'edi, [rsp + 16]', '8b7c2410'),
  (2178, 'x86_64_exact_mov_edi_rsp_20', 'asm_x86_exact_mov_edi_rsp_20_exact', 'mov', 'edi, [rsp + 20]', '8b7c2414'),
  (2179, 'x86_64_exact_mov_esi_rsp_24', 'asm_x86_exact_mov_esi_rsp_24_exact', 'mov', 'esi, [rsp + 24]', '8b742418'),
  (2180, 'x86_64_exact_mov_esi_rsp_28', 'asm_x86_exact_mov_esi_rsp_28_exact', 'mov', 'esi, [rsp + 28]', '8b74241c'),
  (2181, 'x86_64_exact_movzx_esi_byte_r12_rcx_1', 'asm_x86_exact_movzx_esi_byte_r12_rcx_1_exact', 'movzx', 'esi, byte [r12 + rcx + 1]', '410fb6740c01'),
  (2182, 'x86_64_exact_movzx_esi_byte_r13', 'asm_x86_exact_movzx_esi_byte_r13_exact', 'movzx', 'esi, byte [r13]', '410fb67500'),
  (2183, 'x86_64_exact_shl_r15d_4', 'asm_x86_exact_shl_r15d_4_exact', 'shl', 'r15d, 4', '41c1e704'),
  (2184, 'x86_64_exact_sub_eax_rsp_28', 'asm_x86_exact_sub_eax_rsp_28_exact', 'sub', 'eax, [rsp + 28]', '2b44241c'),
  (2185, 'x86_64_exact_sub_esi_eax', 'asm_x86_exact_sub_esi_eax_exact', 'sub', 'esi, eax', '29c6'),
  (2186, 'x86_64_exact_add_r11d_4', 'asm_x86_exact_add_r11d_4_exact', 'add', 'r11d, 4', '4183c304'),
  (2187, 'x86_64_exact_cmp_dword_rsp_56_0', 'asm_x86_exact_cmp_dword_rsp_56_0_exact', 'cmp', 'dword [rsp + 56], 0', '837c243800'),
  (2188, 'x86_64_exact_cmp_eax_rsp_104', 'asm_x86_exact_cmp_eax_rsp_104_exact', 'cmp', 'eax, [rsp + 104]', '3b442468'),
  (2189, 'x86_64_exact_cmp_r11d_16', 'asm_x86_exact_cmp_r11d_16_exact', 'cmp', 'r11d, 16', '4183fb10'),
  (2190, 'x86_64_exact_imul_eax_18', 'asm_x86_exact_imul_eax_18_exact', 'imul', 'eax, 18', '6bc012'),
  (2191, 'x86_64_exact_imul_eax_27', 'asm_x86_exact_imul_eax_27_exact', 'imul', 'eax, 27', '6bc01b'),
  (2192, 'x86_64_exact_imul_eax_9', 'asm_x86_exact_imul_eax_9_exact', 'imul', 'eax, 9', '6bc009'),
  (2193, 'x86_64_exact_lea_r8d_eax_ebx', 'asm_x86_exact_lea_r8d_eax_ebx_exact', 'lea', 'r8d, [eax + ebx]', '67448d0418'),
  (2194, 'x86_64_exact_lea_rdi_rsp_16', 'asm_x86_exact_lea_rdi_rsp_16_exact', 'lea', 'rdi, [rsp + 16]', '488d7c2410'),
  (2195, 'x86_64_exact_mov_rsp_rcx_al', 'asm_x86_exact_mov_rsp_rcx_al_exact', 'mov', '[rsp + rcx], al', '88040c'),
  (2196, 'x86_64_exact_mov_dword_rsp_44_0', 'asm_x86_exact_mov_dword_rsp_44_0_exact', 'mov', 'dword [rsp + 44], 0', 'c744242c00000000'),
  (2197, 'x86_64_exact_mov_eax_rsp_112', 'asm_x86_exact_mov_eax_rsp_112_exact', 'mov', 'eax, [rsp + 112]', '8b442470'),
  (2198, 'x86_64_exact_mov_eax_rsp_80', 'asm_x86_exact_mov_eax_rsp_80_exact', 'mov', 'eax, [rsp + 80]', '8b442450'),
  (2199, 'x86_64_exact_mov_rax_rsp_112', 'asm_x86_exact_mov_rax_rsp_112_exact', 'mov', 'rax, [rsp + 112]', '488b442470'),
  (2200, 'x86_64_exact_movsxd_rax_dword_rsp_20', 'asm_x86_exact_movsxd_rax_dword_rsp_20_exact', 'movsxd', 'rax, dword [rsp + 20]', '4863442414'),
  (2201, 'x86_64_exact_movsxd_rax_dword_rsp_24', 'asm_x86_exact_movsxd_rax_dword_rsp_24_exact', 'movsxd', 'rax, dword [rsp + 24]', '4863442418'),
  (2202, 'x86_64_exact_movzx_edi_byte_r12_rcx', 'asm_x86_exact_movzx_edi_byte_r12_rcx_exact', 'movzx', 'edi, byte [r12 + rcx]', '410fb63c0c'),
  (2203, 'x86_64_exact_movzx_edx_byte_r12_3', 'asm_x86_exact_movzx_edx_byte_r12_3_exact', 'movzx', 'edx, byte [r12 + 3]', '410fb6542403'),
  (2204, 'x86_64_exact_movzx_esi_byte_r12_rcx', 'asm_x86_exact_movzx_esi_byte_r12_rcx_exact', 'movzx', 'esi, byte [r12 + rcx]', '410fb6340c'),
  (2205, 'x86_64_exact_movzx_esi_byte_r13_1', 'asm_x86_exact_movzx_esi_byte_r13_1_exact', 'movzx', 'esi, byte [r13 + 1]', '410fb67501'),
  (2206, 'x86_64_exact_movzx_esi_byte_r13_2', 'asm_x86_exact_movzx_esi_byte_r13_2_exact', 'movzx', 'esi, byte [r13 + 2]', '410fb67502'),
  (2207, 'x86_64_exact_sete_dl', 'asm_x86_exact_sete_dl_exact', 'sete', 'dl', '0f94d2'),
  (2208, 'x86_64_exact_sub_eax_rsp_20', 'asm_x86_exact_sub_eax_rsp_20_exact', 'sub', 'eax, [rsp + 20]', '2b442414'),
  (2209, 'x86_64_exact_sub_ecx_edx', 'asm_x86_exact_sub_ecx_edx_exact', 'sub', 'ecx, edx', '29d1'),
  (2210, 'x86_64_exact_add_ecx_rsp_44', 'asm_x86_exact_add_ecx_rsp_44_exact', 'add', 'ecx, [rsp + 44]', '034c242c'),
  (2211, 'x86_64_exact_add_ecx_r9d', 'asm_x86_exact_add_ecx_r9d_exact', 'add', 'ecx, r9d', '4401c9'),
  (2212, 'x86_64_exact_add_esi_edx', 'asm_x86_exact_add_esi_edx_exact', 'add', 'esi, edx', '01d6'),
  (2213, 'x86_64_exact_cmp_eax_rsp', 'asm_x86_exact_cmp_eax_rsp_exact', 'cmp', 'eax, [rsp]', '3b0424'),
  (2214, 'x86_64_exact_inc_dword_rsp_12', 'asm_x86_exact_inc_dword_rsp_12_exact', 'inc', 'dword [rsp + 12]', 'ff44240c'),
  (2215, 'x86_64_exact_inc_dword_rsp_28', 'asm_x86_exact_inc_dword_rsp_28_exact', 'inc', 'dword [rsp + 28]', 'ff44241c'),
  (2216, 'x86_64_exact_lea_eax_rax_rax2', 'asm_x86_exact_lea_eax_rax_rax2_exact', 'lea', 'eax, [rax + rax * 2]', '8d0440'),
  (2217, 'x86_64_exact_lea_edx_rdx_rdx', 'asm_x86_exact_lea_edx_rdx_rdx_exact', 'lea', 'edx, [rdx + rdx]', '8d1412'),
  (2218, 'x86_64_exact_lea_rdi_rsp_8', 'asm_x86_exact_lea_rdi_rsp_8_exact', 'lea', 'rdi, [rsp + 8]', '488d7c2408'),
  (2219, 'x86_64_exact_mov_r10_rcx_al', 'asm_x86_exact_mov_r10_rcx_al_exact', 'mov', '[r10 + rcx], al', '4188040a'),
  (2220, 'x86_64_exact_mov_r12_rcx_minus_1_al', 'asm_x86_exact_mov_r12_rcx_minus_1_al_exact', 'mov', '[r12 + rcx - 1], al', '4188440cff'),
  (2221, 'x86_64_exact_mov_rdx_rcx4_eax', 'asm_x86_exact_mov_rdx_rcx4_eax_exact', 'mov', '[rdx + rcx * 4], eax', '89048a'),
  (2222, 'x86_64_exact_mov_rsp_16_r8d', 'asm_x86_exact_mov_rsp_16_r8d_exact', 'mov', '[rsp + 16], r8d', '4489442410'),
  (2223, 'x86_64_exact_mov_rsp_72_eax', 'asm_x86_exact_mov_rsp_72_eax_exact', 'mov', '[rsp + 72], eax', '89442448'),
  (2224, 'x86_64_exact_mov_rsp_76_eax', 'asm_x86_exact_mov_rsp_76_eax_exact', 'mov', '[rsp + 76], eax', '8944244c'),
  (2225, 'x86_64_exact_mov_dword_rsp_12_0', 'asm_x86_exact_mov_dword_rsp_12_0_exact', 'mov', 'dword [rsp + 12], 0', 'c744240c00000000'),
  (2226, 'x86_64_exact_mov_dword_rsp_16_0', 'asm_x86_exact_mov_dword_rsp_16_0_exact', 'mov', 'dword [rsp + 16], 0', 'c744241000000000'),
  (2227, 'x86_64_exact_mov_edi_rsp_12', 'asm_x86_exact_mov_edi_rsp_12_exact', 'mov', 'edi, [rsp + 12]', '8b7c240c'),
  (2228, 'x86_64_exact_mov_edi_rsp_8', 'asm_x86_exact_mov_edi_rsp_8_exact', 'mov', 'edi, [rsp + 8]', '8b7c2408'),
  (2229, 'x86_64_exact_mov_edx_r15_rax', 'asm_x86_exact_mov_edx_r15_rax_exact', 'mov', 'edx, [r15 + rax]', '418b1407'),
  (2230, 'x86_64_exact_mov_esi_rsp_20', 'asm_x86_exact_mov_esi_rsp_20_exact', 'mov', 'esi, [rsp + 20]', '8b742414'),
  (2231, 'x86_64_exact_mov_r10_rsp_16', 'asm_x86_exact_mov_r10_rsp_16_exact', 'mov', 'r10, [rsp + 16]', '4c8b542410'),
  (2232, 'x86_64_exact_mov_r9d_rsp_8', 'asm_x86_exact_mov_r9d_rsp_8_exact', 'mov', 'r9d, [rsp + 8]', '448b4c2408'),
  (2233, 'x86_64_exact_mov_rax_rsp_120', 'asm_x86_exact_mov_rax_rsp_120_exact', 'mov', 'rax, [rsp + 120]', '488b442478'),
  (2234, 'x86_64_exact_mov_rcx_rsp_64', 'asm_x86_exact_mov_rcx_rsp_64_exact', 'mov', 'rcx, [rsp + 64]', '488b4c2440'),
  (2235, 'x86_64_exact_mov_rdx_rsp_72', 'asm_x86_exact_mov_rdx_rsp_72_exact', 'mov', 'rdx, [rsp + 72]', '488b542448'),
  (2236, 'x86_64_exact_movsx_eax_word_rdi_rcx2', 'asm_x86_exact_movsx_eax_word_rdi_rcx2_exact', 'movsx', 'eax, word [rdi + rcx * 2]', '0fbf044f'),
  (2237, 'x86_64_exact_movsx_eax_word_rdi', 'asm_x86_exact_movsx_eax_word_rdi_exact', 'movsx', 'eax, word [rdi]', '0fbf07'),
  (2238, 'x86_64_exact_movsxd_rax_ebx', 'asm_x86_exact_movsxd_rax_ebx_exact', 'movsxd', 'rax, ebx', '4863c3'),
  (2239, 'x86_64_exact_movsxd_rax_r15d', 'asm_x86_exact_movsxd_rax_r15d_exact', 'movsxd', 'rax, r15d', '4963c7'),
  (2240, 'x86_64_exact_movzx_eax_byte_r12_rax', 'asm_x86_exact_movzx_eax_byte_r12_rax_exact', 'movzx', 'eax, byte [r12 + rax]', '410fb60404'),
  (2241, 'x86_64_exact_movzx_eax_byte_rsp_64_vp8_lf_edge_limit', 'asm_x86_exact_movzx_eax_byte_rsp_64_vp8_lf_edge_limit_exact', 'movzx', 'eax, byte [rsp + 64 + VP8_LOOP_FILTER_PARAM_EDGE_LIMIT]', '0fb6442440'),
  (2242, 'x86_64_exact_movzx_ecx_sil', 'asm_x86_exact_movzx_ecx_sil_exact', 'movzx', 'ecx, sil', '400fb6ce'),
  (2243, 'x86_64_exact_movzx_edi_byte_r12_1', 'asm_x86_exact_movzx_edi_byte_r12_1_exact', 'movzx', 'edi, byte [r12 + 1]', '410fb67c2401'),
  (2244, 'x86_64_exact_movzx_edi_byte_r12_2', 'asm_x86_exact_movzx_edi_byte_r12_2_exact', 'movzx', 'edi, byte [r12 + 2]', '410fb67c2402'),
  (2245, 'x86_64_exact_movzx_edi_byte_r12_rcx_minus_2', 'asm_x86_exact_movzx_edi_byte_r12_rcx_minus_2_exact', 'movzx', 'edi, byte [r12 + rcx - 2]', '410fb67c0cfe'),
  (2246, 'x86_64_exact_movzx_esi_byte_r12_2', 'asm_x86_exact_movzx_esi_byte_r12_2_exact', 'movzx', 'esi, byte [r12 + 2]', '410fb6742402'),
  (2247, 'x86_64_exact_movzx_esi_byte_r12_3', 'asm_x86_exact_movzx_esi_byte_r12_3_exact', 'movzx', 'esi, byte [r12 + 3]', '410fb6742403'),
  (2248, 'x86_64_exact_movzx_esi_byte_r13_3', 'asm_x86_exact_movzx_esi_byte_r13_3_exact', 'movzx', 'esi, byte [r13 + 3]', '410fb67503'),
  (2249, 'x86_64_exact_sar_eax_vp8_yuv_shift', 'asm_x86_exact_sar_eax_vp8_yuv_shift_exact', 'sar', 'eax, VP8_YUV_SHIFT', 'c1f808'),
  (2250, 'x86_64_exact_shl_ecx_2', 'asm_x86_exact_shl_ecx_2_exact', 'shl', 'ecx, 2', 'c1e102'),
  (2251, 'x86_64_exact_shl_edx_2', 'asm_x86_exact_shl_edx_2_exact', 'shl', 'edx, 2', 'c1e202'),
  (2252, 'x86_64_exact_shl_esi_3', 'asm_x86_exact_shl_esi_3_exact', 'shl', 'esi, 3', 'c1e603'),
  (2253, 'x86_64_exact_shl_r14d_3', 'asm_x86_exact_shl_r14d_3_exact', 'shl', 'r14d, 3', '41c1e603'),
  (2254, 'x86_64_exact_shl_r14d_4', 'asm_x86_exact_shl_r14d_4_exact', 'shl', 'r14d, 4', '41c1e604'),
  (2255, 'x86_64_exact_shl_r15d_3', 'asm_x86_exact_shl_r15d_3_exact', 'shl', 'r15d, 3', '41c1e703'),
  (2256, 'x86_64_exact_add_al_2', 'asm_x86_exact_add_al_2_exact', 'add', 'al, 2', '0402'),
  (2257, 'x86_64_exact_add_dword_rsp_16_eax', 'asm_x86_exact_add_dword_rsp_16_eax_exact', 'add', 'dword [rsp + 16], eax', '01442410'),
  (2258, 'x86_64_exact_add_eax_vp8_lf_mb_edge_adjust', 'asm_x86_exact_add_eax_vp8_lf_mb_edge_adjust_exact', 'add', 'eax, VP8_LOOP_FILTER_MB_EDGE_ADJUST', '83c002'),
  (2259, 'x86_64_exact_add_eax_rsp_72', 'asm_x86_exact_add_eax_rsp_72_exact', 'add', 'eax, [rsp + 72]', '03442448'),
  (2260, 'x86_64_exact_add_eax_rsp_76', 'asm_x86_exact_add_eax_rsp_76_exact', 'add', 'eax, [rsp + 76]', '0344244c'),
  (2261, 'x86_64_exact_add_ecx_4', 'asm_x86_exact_add_ecx_4_exact', 'add', 'ecx, 4', '83c104'),
  (2262, 'x86_64_exact_add_ecx_rsp_28', 'asm_x86_exact_add_ecx_rsp_28_exact', 'add', 'ecx, [rsp + 28]', '034c241c'),
  (2263, 'x86_64_exact_add_r8d_4', 'asm_x86_exact_add_r8d_4_exact', 'add', 'r8d, 4', '4183c004'),
  (2264, 'x86_64_exact_add_r8d_r11d', 'asm_x86_exact_add_r8d_r11d_exact', 'add', 'r8d, r11d', '4501d8'),
  (2265, 'x86_64_exact_and_ebx_vp8_mv_chroma_fraction_mask', 'asm_x86_exact_and_ebx_vp8_mv_chroma_fraction_mask_exact', 'and', 'ebx, VP8_MOTION_VECTOR_CHROMA_FRACTION_MASK', '83e307'),
  (2266, 'x86_64_exact_and_r15d_vp8_mv_chroma_fraction_mask', 'asm_x86_exact_and_r15d_vp8_mv_chroma_fraction_mask_exact', 'and', 'r15d, VP8_MOTION_VECTOR_CHROMA_FRACTION_MASK', '4183e707'),
  (2267, 'x86_64_exact_and_r15d_vp8_mv_fraction_mask', 'asm_x86_exact_and_r15d_vp8_mv_fraction_mask_exact', 'and', 'r15d, VP8_MOTION_VECTOR_FRACTION_MASK', '4183e703'),
  (2268, 'x86_64_exact_cmp_rsp_vp8_out_cap_rax', 'asm_x86_exact_cmp_rsp_vp8_out_cap_rax_exact', 'cmp', '[rsp + VP8_DECODE_STACK_OUT_CAP], rax', '48398424910b0000'),
  (2269, 'x86_64_exact_cmp_byte_r12_vp8_segment_update_map_0', 'asm_x86_exact_cmp_byte_r12_vp8_segment_update_map_0_exact', 'cmp', 'byte [r12 + VP8_COMPRESSED_HEADER_SEGMENT + VP8_SEGMENT_UPDATE_MAP], 0', '41807c242000'),
  (2270, 'x86_64_exact_cmp_byte_r12_vp8_use_skip_0', 'asm_x86_exact_cmp_byte_r12_vp8_use_skip_0_exact', 'cmp', 'byte [r12 + VP8_COMPRESSED_HEADER_USE_SKIP], 0', '41807c244300'),
  (2271, 'x86_64_exact_cmp_byte_rsp_vp8_tag_frame_type_key', 'asm_x86_exact_cmp_byte_rsp_vp8_tag_frame_type_key_exact', 'cmp', 'byte [rsp + VP8_TAG_DESC_FRAME_TYPE], VP8_FRAME_TYPE_KEY', '803c2400'),
  (2272, 'x86_64_exact_cmp_byte_rsp_rbx_0', 'asm_x86_exact_cmp_byte_rsp_rbx_0_exact', 'cmp', 'byte [rsp + rbx], 0', '803c1c00'),
  (2273, 'x86_64_exact_cmp_dword_rsp_12_0', 'asm_x86_exact_cmp_dword_rsp_12_0_exact', 'cmp', 'dword [rsp + 12], 0', '837c240c00'),
  (2274, 'x86_64_exact_cmp_dword_rsp_28_0', 'asm_x86_exact_cmp_dword_rsp_28_0_exact', 'cmp', 'dword [rsp + 28], 0', '837c241c00'),
  (2275, 'x86_64_exact_cmp_dword_rsp_32_0', 'asm_x86_exact_cmp_dword_rsp_32_0_exact', 'cmp', 'dword [rsp + 32], 0', '837c242000'),
  (2276, 'x86_64_exact_cmp_eax_minus_32768', 'asm_x86_exact_cmp_eax_minus_32768_exact', 'cmp', 'eax, -32768', '3d0080ffff'),
  (2277, 'x86_64_exact_cmp_eax_32767', 'asm_x86_exact_cmp_eax_32767_exact', 'cmp', 'eax, 32767', '3dff7f0000'),
  (2278, 'x86_64_exact_cmp_eax_vp8_reference_copy_last', 'asm_x86_exact_cmp_eax_vp8_reference_copy_last_exact', 'cmp', 'eax, VP8_REFERENCE_COPY_LAST', '83f801'),
  (2279, 'x86_64_exact_cmp_eax_vp8_reference_name_alternate', 'asm_x86_exact_cmp_eax_vp8_reference_name_alternate_exact', 'cmp', 'eax, VP8_REFERENCE_NAME_ALTERNATE', '83f802'),
  (2280, 'x86_64_exact_cmp_eax_vp8_reference_name_golden', 'asm_x86_exact_cmp_eax_vp8_reference_name_golden_exact', 'cmp', 'eax, VP8_REFERENCE_NAME_GOLDEN', '83f801'),
  (2281, 'x86_64_exact_cmp_eax_vp8_reference_name_last', 'asm_x86_exact_cmp_eax_vp8_reference_name_last_exact', 'cmp', 'eax, VP8_REFERENCE_NAME_LAST', '83f800'),
  (2282, 'x86_64_exact_cmp_eax_rsp_vp8_mb_height', 'asm_x86_exact_cmp_eax_rsp_vp8_mb_height_exact', 'cmp', 'eax, [rsp + VP8_DECODE_STACK_MB_HEIGHT]', '3b8424bd0b0000'),
  (2283, 'x86_64_exact_cmp_eax_rsp_vp8_mb_width', 'asm_x86_exact_cmp_eax_rsp_vp8_mb_width_exact', 'cmp', 'eax, [rsp + VP8_DECODE_STACK_MB_WIDTH]', '3b8424b90b0000'),
  (2284, 'x86_64_exact_cmp_ebx_vp8_luma_mode_b_pred', 'asm_x86_exact_cmp_ebx_vp8_luma_mode_b_pred_exact', 'cmp', 'ebx, VP8_LUMA_MODE_B_PRED', '83fb04'),
  (2285, 'x86_64_exact_cmp_edx_vp8_coeff_type_count', 'asm_x86_exact_cmp_edx_vp8_coeff_type_count_exact', 'cmp', 'edx, VP8_COEFF_TYPE_COUNT', '83fa04'),
  (2286, 'x86_64_exact_cmp_edx_vp8_frame_type_inter', 'asm_x86_exact_cmp_edx_vp8_frame_type_inter_exact', 'cmp', 'edx, VP8_FRAME_TYPE_INTER', '83fa01'),
  (2287, 'x86_64_exact_cmp_esi_vp8_max_macroblock_columns', 'asm_x86_exact_cmp_esi_vp8_max_macroblock_columns_exact', 'cmp', 'esi, VP8_MAX_MACROBLOCK_COLUMNS', '81fe00040000'),
  (2288, 'x86_64_exact_cmp_r10d_rsp', 'asm_x86_exact_cmp_r10d_rsp_exact', 'cmp', 'r10d, [rsp]', '443b1424'),
  (2289, 'x86_64_exact_cmp_r11d_vp8_block_size', 'asm_x86_exact_cmp_r11d_vp8_block_size_exact', 'cmp', 'r11d, VP8_BLOCK_SIZE', '4183fb04'),
  (2290, 'x86_64_exact_cmp_r11d_rsp_12', 'asm_x86_exact_cmp_r11d_rsp_12_exact', 'cmp', 'r11d, [rsp + 12]', '443b5c240c'),
  (2291, 'x86_64_exact_cmp_r15d_vp8_coeff_band_entries_minus_1', 'asm_x86_exact_cmp_r15d_vp8_coeff_band_entries_minus_1_exact', 'cmp', 'r15d, VP8_COEFF_BAND_ENTRIES - 1', '4183ff10'),
  (2292, 'x86_64_exact_cmp_r8d_vp8_coeff_context_count', 'asm_x86_exact_cmp_r8d_vp8_coeff_context_count_exact', 'cmp', 'r8d, VP8_COEFF_CONTEXT_COUNT', '4183f803'),
  (2293, 'x86_64_exact_cmp_r8d_r13d', 'asm_x86_exact_cmp_r8d_r13d_exact', 'cmp', 'r8d, r13d', '4539e8'),
  (2294, 'x86_64_exact_cmp_r9d_vp8_mb_prediction_intra', 'asm_x86_exact_cmp_r9d_vp8_mb_prediction_intra_exact', 'cmp', 'r9d, VP8_MACROBLOCK_PREDICTION_INTRA', '4183f900'),
  (2295, 'x86_64_exact_imul_eax_vp8_token_partition_size_bytes', 'asm_x86_exact_imul_eax_vp8_token_partition_size_bytes_exact', 'imul', 'eax, VP8_TOKEN_PARTITION_SIZE_BYTES', '6bc003'),
  (2296, 'x86_64_exact_imul_eax_rsp_vp8_chroma_height', 'asm_x86_exact_imul_eax_rsp_vp8_chroma_height_exact', 'imul', 'eax, [rsp + VP8_DECODE_STACK_CHROMA_HEIGHT]', '0faf8424750b0000'),
  (2297, 'x86_64_exact_imul_eax_rsp_vp8_height', 'asm_x86_exact_imul_eax_rsp_vp8_height_exact', 'imul', 'eax, [rsp + VP8_DECODE_STACK_HEIGHT]', '0faf84246d0b0000'),
  (2298, 'x86_64_exact_imul_ecx_vp8_motion_vector_size', 'asm_x86_exact_imul_ecx_vp8_motion_vector_size_exact', 'imul', 'ecx, VP8_MOTION_VECTOR_SIZE', '6bc904'),
  (2299, 'x86_64_exact_imul_r11d_r12d', 'asm_x86_exact_imul_r11d_r12d_exact', 'imul', 'r11d, r12d', '450fafdc'),
  (2300, 'x86_64_exact_mov_edx_av1_cdf_prob_top', 'asm_x86_exact_mov_edx_av1_cdf_prob_top_exact', 'mov', 'edx, AV1_CDF_PROB_TOP', 'ba00800000'),
  (2301, 'x86_64_exact_mov_rdx_rcx8_minus_8_rax', 'asm_x86_exact_mov_rdx_rcx8_minus_8_rax_exact', 'mov', '[rdx + rcx*8 - 8], rax', '488944caf8'),
  (2302, 'x86_64_exact_cmp_rdx_error_arithmetic_trap', 'asm_x86_exact_cmp_rdx_error_arithmetic_trap_exact', 'cmp', 'rdx, ERROR_ARITHMETIC_TRAP', '4883fa11'),
  (2303, 'x86_64_exact_cmp_byte_rsi_rdx_0', 'asm_x86_exact_cmp_byte_rsi_rdx_0_exact', 'cmp', 'byte [rsi + rdx], 0', '803c1600');

insert into asm_exact_fixed_encoding_fact(encoding_id, isa_id, name, rule_name, op_name, operand_text, fixed_hex) values
  (1953, 4, 'arm32_exact_add_r3_r3_imm_1', 'asm_arm32_exact_add_r3_r3_imm_1_exact', 'add', 'r3, r3, #1', '013083e2'),
  (1954, 4, 'arm32_exact_cmp_r4_imm_0', 'asm_arm32_exact_cmp_r4_imm_0_exact', 'cmp', 'r4, #0', '000054e3'),
  (1955, 4, 'arm32_exact_ldr_r0_ptr_r1_r0', 'asm_arm32_exact_ldr_r0_ptr_r1_r0_exact', 'ldr', 'r0, [r1, r0]', '000091e7'),
  (1956, 4, 'arm32_exact_ldr_r0_ptr_r4_post_4', 'asm_arm32_exact_ldr_r0_ptr_r4_post_4_exact', 'ldr', 'r0, [r4], #4', '040094e4'),
  (1957, 4, 'arm32_exact_ldr_r1_ptr_r1', 'asm_arm32_exact_ldr_r1_ptr_r1_exact', 'ldr', 'r1, [r1]', '001091e5'),
  (1958, 4, 'arm32_exact_mov_r0_r4', 'asm_arm32_exact_mov_r0_r4_exact', 'mov', 'r0, r4', '0400a0e1'),
  (1959, 4, 'arm32_exact_mov_r1_imm_1', 'asm_arm32_exact_mov_r1_imm_1_exact', 'mov', 'r1, #1', '0110a0e3'),
  (1960, 4, 'arm32_exact_orr_r0_r0_r1', 'asm_arm32_exact_orr_r0_r0_r1_exact', 'orr', 'r0, r0, r1', '010080e1'),
  (1961, 4, 'arm32_exact_push_r4_r5_r6_r7_r8_r9_r10_r11_lr', 'asm_arm32_exact_push_r4_r5_r6_r7_r8_r9_r10_r11_lr_exact', 'push', '{r4, r5, r6, r7, r8, r9, r10, r11, lr}', 'f04f2de9');

insert or ignore into encoding_pattern(encoding_id, name, isa_id, encoding_kind, fixed_hex, immediate_type_id, immediate_operand_index, flags, object_path)
select asm_exact_fixed_encoding_fact.encoding_id,
       asm_exact_fixed_encoding_fact.name,
       asm_exact_fixed_encoding_fact.isa_id,
       1,
       asm_exact_fixed_encoding_fact.fixed_hex,
       null,
       -1,
       0,
       'kernel/x86_64/object/encoding/' || isa.name || '/' || asm_exact_fixed_encoding_fact.name || '.erobj'
from asm_exact_fixed_encoding_fact
join isa using (isa_id);

insert or ignore into asm_dsl_rule(line_kind, op_name, operation_kind_id, instruction_path, form_path, encoding_id, rule_name, exact_operand_text, flags)
select 3,
       op_name,
       null,
       'kernel/x86_64/object/instruction/' || isa.name || '/' || op_name || '.erobj',
       null,
       encoding_id,
       rule_name,
       operand_text,
       0
from asm_exact_fixed_encoding_fact
join isa using (isa_id);


insert into asm_dsl_source(asm_source_id, source_object_path, module_name, language_id) values
  (1, 'kernel/test/test_flat_runtime.asm.erobj', 'kernel_test_flat_runtime', 7);

insert into asm_dsl_line(asm_source_id, line_id, line_kind, label_name, op_name, operand_text, raw_text) values
  (1, 1, 1, null, 'er_fn', 'er_bss_zero', 'er_fn er_bss_zero'),
  (1, 2, 3, null, 'mov', 'rcx, rsi', '    mov rcx, rsi'),
  (1, 3, 3, null, 'sub', 'rcx, rdi', '    sub rcx, rdi'),
  (1, 4, 3, null, 'jle', '.done', '    jle .done'),
  (1, 5, 3, null, 'xor', 'eax, eax', '    xor eax, eax'),
  (1, 6, 3, null, 'cld', null, '    cld'),
  (1, 7, 3, null, 'shr', 'rcx, 3', '    shr rcx, 3'),
  (1, 8, 3, null, 'rep', 'stosq', '    rep stosq'),
  (1, 9, 2, '.done', null, null, '.done:'),
  (1, 10, 3, null, 'ret', null, '    ret');

insert into asm_dsl_function_span(asm_source_id, asm_function_id, function_name, start_line_id, end_line_id, target_isa_id) values
  (1, 1, 'er_bss_zero', 1, 10, 1);

create view asm_dsl_imported_functions as
select asm_dsl_source.module_name,
       asm_dsl_function_span.function_name,
       isa.name as target_isa,
       asm_dsl_function_span.start_line_id,
       asm_dsl_function_span.end_line_id
from asm_dsl_function_span
join asm_dsl_source using (asm_source_id)
join isa on isa.isa_id = asm_dsl_function_span.target_isa_id;

create view asm_dsl_parsed_operations as
select asm_dsl_source.module_name,
       asm_dsl_function_span.function_name,
       asm_dsl_line.line_id,
       asm_dsl_line.line_kind,
       asm_dsl_line.op_name,
       asm_dsl_line.operand_text,
       asm_dsl_line.label_name,
       asm_dsl_rule.rule_name,
       asm_dsl_rule.operation_kind_id,
       asm_dsl_rule.instruction_path,
       asm_dsl_rule.form_path,
       asm_dsl_rule.encoding_id,
       asm_dsl_line.raw_text
from asm_dsl_line
join asm_dsl_source using (asm_source_id)
join asm_dsl_function_span
  on asm_dsl_function_span.asm_source_id = asm_dsl_line.asm_source_id
 and asm_dsl_line.line_id between asm_dsl_function_span.start_line_id and asm_dsl_function_span.end_line_id
left join asm_dsl_rule
  on asm_dsl_rule.asm_rule_id = (
    select candidate_rule.asm_rule_id
    from asm_dsl_rule candidate_rule
    where candidate_rule.line_kind = asm_dsl_line.line_kind
      and candidate_rule.op_name = coalesce(asm_dsl_line.op_name, '')
      and (candidate_rule.exact_operand_text is null
           or candidate_rule.exact_operand_text = coalesce(asm_dsl_line.operand_text, ''))
    order by case when candidate_rule.exact_operand_text is null then 1 else 0 end,
             candidate_rule.asm_rule_id
    limit 1
  )
order by asm_dsl_line.line_id;

create view asm_dsl_unrecognized_syntax as
select module_name, function_name, line_id, op_name, operand_text, raw_text
from asm_dsl_parsed_operations
where line_kind in (3, 4, 5) and rule_name is null;

create view asm_dsl_rule_gaps as
select 'syntax_without_rule' as gap_kind,
       module_name,
       function_name,
       line_id,
       coalesce(op_name, label_name, '') as subject,
       raw_text
from asm_dsl_parsed_operations
where line_kind in (3, 4, 5) and rule_name is null
union all
select 'rule_without_encoding', module_name, function_name, line_id, op_name, raw_text
from asm_dsl_parsed_operations
where rule_name is not null
  and line_kind = 3
  and instruction_path is not null
  and encoding_id is null
union all
select 'macro_without_lowering', module_name, function_name, line_id, op_name, raw_text
from asm_dsl_parsed_operations
where rule_name is not null
  and line_kind = 3
  and instruction_path is null
  and op_name glob 'er_*';

create view asm_dsl_materializable_instruction_stream as
select module_name,
       function_name,
       line_id as sequence,
       op_name,
       instruction_path,
       form_path,
       encoding_id
from asm_dsl_parsed_operations
where encoding_id is not null
order by line_id;

create view asm_dsl_materializable_hex as
select function_name,
       group_concat(fixed_hex, '') as hex_bytes
from (
  select asm_dsl_materializable_instruction_stream.function_name,
         asm_dsl_materializable_instruction_stream.sequence,
         encoding_pattern.fixed_hex
  from asm_dsl_materializable_instruction_stream
  join encoding_pattern using (encoding_id)
  order by asm_dsl_materializable_instruction_stream.function_name,
           asm_dsl_materializable_instruction_stream.sequence
)
group by function_name;

create view asm_dsl_agent_next_gaps as
select gap_kind, module_name, function_name, line_id, subject, raw_text
from asm_dsl_rule_gaps
order by function_name, line_id, gap_kind;

create table repo_file (
  repo_file_id integer primary key,
  path text not null unique,
  mode integer not null,
  mtime integer not null,
  byte_len integer not null,
  ext text not null,
  file_kind text not null,
  content blob not null
);

insert into repo_file(path, mode, mtime, byte_len, ext, file_kind, content)
select name,
       mode,
       mtime,
       length(data),
       case
         when name like '%.asm.erobj' then 'asm.erobj'
         when name like '%.asm' then 'asm'
         when name like '%.inc' then 'inc'
         when name like '%.sql' then 'sql'
         when name like '%.md' then 'md'
         when name like '%.ld' then 'ld'
         else ''
       end,
       case
         when name like '%.asm.erobj' then 'source_object_asm'
         when name like '%.asm' then 'asm'
         when name like '%.inc' then 'asm_include'
         when name like '%.sql' then 'sql'
         when name like '%.md' then 'doc'
         when name like '%.ld' then 'linker_script'
         else 'other'
       end,
       data
from fsdir('kernel')
where data is not null
  and length(data) < 2000000
  and (
    name like '%.asm' or name like '%.inc' or name like '%.asm.erobj'
    or name like '%.sql' or name like '%.md' or name like '%.ld'
  );

insert into repo_file(path, mode, mtime, byte_len, ext, file_kind, content) values
  ('AGENTS.md', 0, 0, length(readfile('AGENTS.md')), 'md', 'doc', readfile('AGENTS.md')),
  ('README.md', 0, 0, length(readfile('README.md')), 'md', 'doc', readfile('README.md')),
  ('CHANGELOG.md', 0, 0, length(readfile('CHANGELOG.md')), 'md', 'doc', readfile('CHANGELOG.md'));

create view repo_file_summary as
select file_kind, count(*) as file_count, sum(byte_len) as total_bytes
from repo_file
group by file_kind;

create view repo_asm_candidates as
select repo_file_id, path, byte_len
from repo_file
where file_kind in ('asm','asm_include','source_object_asm')
order by path;

create view repo_source_object_roots as
select repo_file_id, path, byte_len
from repo_file
where file_kind = 'source_object_asm'
order by path;

create table repo_asm_line (
  repo_file_id integer not null references repo_file(repo_file_id),
  line_no integer not null,
  text text not null,
  primary key (repo_file_id, line_no)
);

create table repo_asm_function_decl (
  repo_file_id integer not null references repo_file(repo_file_id),
  line_no integer not null,
  function_name text not null,
  declaration_text text not null,
  primary key (repo_file_id, line_no),
  unique (repo_file_id, function_name)
);

with recursive lines(repo_file_id, line_no, rest, line) as (
  select repo_file_id,
         1,
         replace(cast(case
           when file_kind = 'source_object_asm' then substr(content, 149)
           else content
         end as text), char(13), '') || char(10),
         ''
  from repo_file
  where file_kind in ('asm', 'source_object_asm')
  union all
  select repo_file_id,
         line_no + 1,
         substr(rest, instr(rest, char(10)) + 1),
         substr(rest, 1, instr(rest, char(10)) - 1)
  from lines
  where rest <> '' and instr(rest, char(10)) > 0
)
insert into repo_asm_line(repo_file_id, line_no, text)
select repo_file_id, line_no - 1, line
from lines
where line_no > 1;

create table repo_asm_include_line (
  repo_file_id integer not null references repo_file(repo_file_id),
  line_no integer not null,
  text text not null,
  primary key (repo_file_id, line_no)
);

with recursive lines(repo_file_id, line_no, rest, line) as (
  select repo_file_id,
         1,
         replace(cast(content as text), char(13), '') || char(10),
         ''
  from repo_file
  where file_kind = 'asm_include'
  union all
  select repo_file_id,
         line_no + 1,
         substr(rest, instr(rest, char(10)) + 1),
         substr(rest, 1, instr(rest, char(10)) - 1)
  from lines
  where rest <> '' and instr(rest, char(10)) > 0
)
insert into repo_asm_include_line(repo_file_id, line_no, text)
select repo_file_id, line_no - 1, line
from lines
where line_no > 1;

insert or ignore into repo_asm_function_decl(repo_file_id, line_no, function_name, declaration_text)
select repo_file_id,
       line_no,
       trim(substr(trim(text), 7)),
       text
from repo_asm_line
where trim(text) glob 'er_fn *'
  and trim(substr(trim(text), 7)) <> ''
union all
select repo_file_id,
       line_no,
       trim(substr(trim(text), 8)),
       text
from repo_asm_line
join repo_file using (repo_file_id)
where trim(text) glob 'global *'
  and repo_file.file_kind = 'source_object_asm'
  and trim(substr(trim(text), 8)) <> ''
  and instr(trim(substr(trim(text), 8)), '%') = 0
  and instr(trim(substr(trim(text), 8)), ',') = 0;

create view repo_asm_function_inventory as
select repo_file.path,
       repo_asm_function_decl.line_no,
       repo_asm_function_decl.function_name
from repo_asm_function_decl
join repo_file using (repo_file_id)
order by repo_file.path, repo_asm_function_decl.line_no;

create view repo_asm_function_span as
select function_decl.repo_file_id,
       function_decl.function_name,
       function_decl.line_no as start_line_no,
       coalesce((select min(next_decl.line_no) - 1
                 from repo_asm_function_decl next_decl
                 where next_decl.repo_file_id = function_decl.repo_file_id
                   and next_decl.line_no > function_decl.line_no),
                (select max(line_no)
                 from repo_asm_line function_line
                 where function_line.repo_file_id = function_decl.repo_file_id)) as end_line_no
from repo_asm_function_decl function_decl;

create view repo_asm_function_lines as
select repo_file.path,
       repo_asm_function_span.repo_file_id,
       repo_asm_function_span.function_name,
       repo_asm_line.line_no,
       repo_asm_line.text
from repo_asm_function_span
join repo_asm_line
  on repo_asm_line.repo_file_id = repo_asm_function_span.repo_file_id
 and repo_asm_line.line_no between repo_asm_function_span.start_line_no and repo_asm_function_span.end_line_no
join repo_file on repo_file.repo_file_id = repo_asm_function_span.repo_file_id;

create table repo_asm_operation as
with trimmed as (
  select repo_file.path,
         repo_asm_line.repo_file_id,
         coalesce(repo_asm_function_span.function_name, '') as function_name,
         case
           when repo_file.path like 'kernel/arm/%' then 4
           when repo_file.path like 'kernel/test/test_pi_%' then 4
           else 1
         end as target_isa_id,
         repo_asm_line.line_no,
         repo_asm_line.text,
         trim(replace(repo_asm_line.text, char(9), ' ')) as t
  from repo_asm_line
  join repo_file using (repo_file_id)
  left join repo_asm_function_span
    on repo_asm_function_span.repo_file_id = repo_asm_line.repo_file_id
   and repo_asm_line.line_no between repo_asm_function_span.start_line_no and repo_asm_function_span.end_line_no
  where repo_file.file_kind in ('asm', 'source_object_asm')
), parsed as (
  select path,
         repo_file_id,
         function_name,
         target_isa_id,
         line_no,
         text,
         t,
         case
           when t = '' then 0
           when substr(t,1,1) = ';' then 0
            when t glob '*:' then 2
            when t glob '%include*' then 4
            when t glob '* equ *' then 5
            when t glob 'er_fn *' then 1
            when t glob 'global *' then 4
            when substr(t,1,1) = '%' then 4
            else 3
          end as line_kind,
         case
           when t = '' or substr(t,1,1) = ';' then null
           when t glob '.*:' then null
           when instr(t, ' ') = 0 then t
           else substr(t, 1, instr(t, ' ') - 1)
         end as op_name,
          case
            when instr(t, ' ') = 0 then null
            when instr(substr(t, instr(t, ' ') + 1), ';') > 0 then
              trim(substr(substr(t, instr(t, ' ') + 1), 1, instr(substr(t, instr(t, ' ') + 1), ';') - 1))
            else trim(substr(t, instr(t, ' ') + 1))
          end as operand_text
  from trimmed
)
select path, repo_file_id, function_name, target_isa_id, line_no, line_kind, op_name, operand_text, text as raw_text
from parsed
where line_kind <> 0;

create index repo_asm_operation_line_idx on repo_asm_operation(repo_file_id, function_name, line_no);
create index repo_asm_operation_op_idx on repo_asm_operation(line_kind, op_name, operand_text);
create index repo_asm_operation_path_idx on repo_asm_operation(path);

create table repo_asm_include_edge_fact as
select path as source_path,
       repo_file_id as source_repo_file_id,
       line_no,
       trim(operand_text, '"') as include_path,
       case
         when trim(operand_text, '"') like 'kernel/%' then trim(operand_text, '"')
         when path like 'kernel/x86_64/wasm/%'
          and instr(trim(operand_text, '"'), '/') = 0 then 'kernel/x86_64/wasm/' || trim(operand_text, '"')
         else 'kernel/' || trim(operand_text, '"')
       end as target_path
from repo_asm_operation
where op_name = '%include'
  and operand_text is not null
union all
select repo_file.path as source_path,
       include_line.repo_file_id as source_repo_file_id,
       include_line.line_no,
       trim(trim(substr(t, 10)), '"') as include_path,
       case
         when trim(trim(substr(t, 10)), '"') like 'kernel/%' then trim(trim(substr(t, 10)), '"')
         when trim(trim(substr(t, 10)), '"') like 'x86_64/%' then 'kernel/' || trim(trim(substr(t, 10)), '"')
         when repo_file.path like 'kernel/x86_64/wasm/%'
          and instr(trim(trim(substr(t, 10)), '"'), '/') = 0 then 'kernel/x86_64/wasm/' || trim(trim(substr(t, 10)), '"')
         else 'kernel/' || trim(trim(substr(t, 10)), '"')
       end as target_path
from (
  select repo_file_id,
         line_no,
         case
           when instr(trim(replace(text, char(9), ' ')), ';') > 0 then
             trim(substr(trim(replace(text, char(9), ' ')), 1, instr(trim(replace(text, char(9), ' ')), ';') - 1))
           else trim(replace(text, char(9), ' '))
         end as t
  from repo_asm_include_line
) include_line
join repo_file using (repo_file_id)
where t like '%include %';

create index repo_asm_include_edge_fact_source_idx on repo_asm_include_edge_fact(source_path, target_path);
create index repo_asm_include_edge_fact_target_idx on repo_asm_include_edge_fact(target_path, source_path);

create table repo_asm_include_closure_fact as
with recursive include_closure(source_path, target_path, depth) as (
  select source_path, target_path, 1
  from repo_asm_include_edge_fact
  union
  select include_closure.source_path,
         include_edge.target_path,
         include_closure.depth + 1
  from include_closure
  join repo_asm_include_edge_fact include_edge
    on include_edge.source_path = include_closure.target_path
  where include_closure.depth < 8
)
select source_path,
       target_path,
       min(depth) as depth
from include_closure
group by source_path, target_path;

create index repo_asm_include_closure_fact_source_idx on repo_asm_include_closure_fact(source_path, target_path);
create index repo_asm_include_closure_fact_target_idx on repo_asm_include_closure_fact(target_path, source_path);

create view repo_asm_significant_line as
select repo_file.path,
       repo_asm_line.repo_file_id,
       repo_asm_line.line_no,
       repo_asm_line.text,
       trim(replace(repo_asm_line.text, char(9), ' ')) as trimmed_text
from repo_asm_line
join repo_file using (repo_file_id)
where trim(replace(repo_asm_line.text, char(9), ' ')) <> ''
  and substr(trim(replace(repo_asm_line.text, char(9), ' ')), 1, 1) <> ';';

create view repo_asm_unparsed_significant_line as
select line.path,
       line.repo_file_id,
       line.line_no,
       line.text,
       'unparsed_significant_line' as gap_kind
from repo_asm_significant_line line
left join repo_asm_operation operation
  on operation.repo_file_id = line.repo_file_id
 and operation.line_no = line.line_no
where operation.line_no is null;

create table repo_asm_parse_coverage as
select repo_file.path,
       repo_file.repo_file_id,
       count(line.line_no) as significant_line_count,
       sum(case when operation.line_no is not null then 1 else 0 end) as parsed_line_count,
       sum(case when operation.line_no is null then 1 else 0 end) as unparsed_line_count,
       (100 * sum(case when operation.line_no is not null then 1 else 0 end)) / count(line.line_no) as parsed_percent
from repo_file
join repo_asm_significant_line line using (repo_file_id)
left join repo_asm_operation operation
  on operation.repo_file_id = line.repo_file_id
 and operation.line_no = line.line_no
where repo_file.file_kind in ('asm', 'source_object_asm')
group by repo_file.path;

create unique index repo_asm_parse_coverage_path_idx on repo_asm_parse_coverage(path);
create index repo_asm_parse_coverage_unparsed_idx on repo_asm_parse_coverage(unparsed_line_count);

create view repo_asm_rule_gaps as
select repo_asm_operation.path,
       repo_asm_operation.function_name,
       repo_asm_operation.line_no,
       repo_asm_operation.target_isa_id,
       repo_asm_operation.line_kind,
       repo_asm_operation.op_name,
       repo_asm_operation.operand_text,
       repo_asm_operation.raw_text,
       case
         when asm_dsl_rule.asm_rule_id is null then 'syntax_without_rule'
         when repo_asm_operation.line_kind = 3
          and asm_dsl_rule.instruction_path is not null
          and asm_dsl_rule.encoding_id is null then 'rule_without_encoding'
         when repo_asm_operation.line_kind = 3
          and asm_dsl_rule.instruction_path is null
          and repo_asm_operation.op_name glob 'er_*' then 'macro_without_lowering'
       end as gap_kind
from repo_asm_operation
left join asm_dsl_rule
  on asm_dsl_rule.asm_rule_id = (
    select candidate_rule.asm_rule_id
    from asm_dsl_rule candidate_rule
    where candidate_rule.line_kind = repo_asm_operation.line_kind
      and candidate_rule.op_name = coalesce(repo_asm_operation.op_name, '')
      and (candidate_rule.exact_operand_text is null
           or candidate_rule.exact_operand_text = coalesce(repo_asm_operation.operand_text, ''))
      and (candidate_rule.encoding_id is null
           or exists (select 1
                      from encoding_pattern candidate_encoding
                      where candidate_encoding.encoding_id = candidate_rule.encoding_id
                        and candidate_encoding.isa_id = repo_asm_operation.target_isa_id))
    order by case when candidate_rule.exact_operand_text is null then 1 else 0 end,
             candidate_rule.asm_rule_id
    limit 1
  )
where gap_kind is not null;

create view repo_asm_gap_summary as
select gap_kind,
       op_name,
       count(*) as occurrence_count,
       count(distinct path) as file_count,
       count(distinct function_name) as function_count
from repo_asm_rule_gaps
group by gap_kind, op_name
order by occurrence_count desc, op_name;

create view exact_asm_encoding_fact as
select asm_dsl_rule.op_name,
       asm_dsl_rule.exact_operand_text as operand_text,
       asm_dsl_rule.rule_name,
       asm_dsl_rule.instruction_path,
       asm_dsl_rule.form_path,
       asm_dsl_rule.encoding_id,
       encoding_pattern.fixed_hex,
       encoding_pattern.object_path as encoding_object_path
from asm_dsl_rule
join encoding_pattern using (encoding_id)
where asm_dsl_rule.encoding_id is not null
  and asm_dsl_rule.exact_operand_text is not null;

create table repo_asm_rule_match as
select repo_asm_operation.path,
       repo_asm_operation.repo_file_id,
       repo_asm_operation.function_name,
       repo_asm_operation.line_no,
       repo_asm_operation.target_isa_id,
       repo_asm_operation.line_kind,
       repo_asm_operation.op_name,
       repo_asm_operation.operand_text,
       repo_asm_operation.raw_text,
       asm_dsl_rule.asm_rule_id,
       asm_dsl_rule.rule_name,
       asm_dsl_rule.instruction_path,
       asm_dsl_rule.form_path,
       asm_dsl_rule.encoding_id,
       encoding_pattern.fixed_hex
from repo_asm_operation
left join asm_dsl_rule
  on asm_dsl_rule.asm_rule_id = (
    select candidate_rule.asm_rule_id
    from asm_dsl_rule candidate_rule
    where candidate_rule.line_kind = repo_asm_operation.line_kind
      and candidate_rule.op_name = coalesce(repo_asm_operation.op_name, '')
      and (candidate_rule.exact_operand_text is null
           or candidate_rule.exact_operand_text = coalesce(repo_asm_operation.operand_text, ''))
      and (candidate_rule.encoding_id is null
           or exists (select 1
                      from encoding_pattern candidate_encoding
                      where candidate_encoding.encoding_id = candidate_rule.encoding_id
                        and candidate_encoding.isa_id = repo_asm_operation.target_isa_id))
    order by case when candidate_rule.exact_operand_text is null then 1 else 0 end,
             candidate_rule.asm_rule_id
    limit 1
  )
left join encoding_pattern using (encoding_id);

create index repo_asm_rule_match_line_idx on repo_asm_rule_match(repo_file_id, function_name, line_no);
create index repo_asm_rule_match_encoding_idx on repo_asm_rule_match(encoding_id);
create index repo_asm_rule_match_rule_idx on repo_asm_rule_match(op_name, operand_text, rule_name);

create table x86_register_encoding_fact (
  register_name text primary key,
  width_bits integer not null,
  reg_code integer not null,
  requires_rex integer not null
);

insert into x86_register_encoding_fact(register_name, width_bits, reg_code, requires_rex) values
  ('al', 8, 0, 0), ('cl', 8, 1, 0), ('dl', 8, 2, 0), ('bl', 8, 3, 0),
  ('spl', 8, 4, 1), ('bpl', 8, 5, 1), ('sil', 8, 6, 1), ('dil', 8, 7, 1),
  ('r8b', 8, 8, 1), ('r9b', 8, 9, 1), ('r10b', 8, 10, 1), ('r11b', 8, 11, 1),
  ('r12b', 8, 12, 1), ('r13b', 8, 13, 1), ('r14b', 8, 14, 1), ('r15b', 8, 15, 1),
  ('ax', 16, 0, 0), ('cx', 16, 1, 0), ('dx', 16, 2, 0), ('bx', 16, 3, 0),
  ('sp', 16, 4, 0), ('bp', 16, 5, 0), ('si', 16, 6, 0), ('di', 16, 7, 0),
  ('r8w', 16, 8, 1), ('r9w', 16, 9, 1), ('r10w', 16, 10, 1), ('r11w', 16, 11, 1),
  ('r12w', 16, 12, 1), ('r13w', 16, 13, 1), ('r14w', 16, 14, 1), ('r15w', 16, 15, 1),
  ('eax', 32, 0, 0), ('ecx', 32, 1, 0), ('edx', 32, 2, 0), ('ebx', 32, 3, 0),
  ('esp', 32, 4, 0), ('ebp', 32, 5, 0), ('esi', 32, 6, 0), ('edi', 32, 7, 0),
  ('r8d', 32, 8, 1), ('r9d', 32, 9, 1), ('r10d', 32, 10, 1), ('r11d', 32, 11, 1),
  ('r12d', 32, 12, 1), ('r13d', 32, 13, 1), ('r14d', 32, 14, 1), ('r15d', 32, 15, 1),
  ('rax', 64, 0, 0), ('rcx', 64, 1, 0), ('rdx', 64, 2, 0), ('rbx', 64, 3, 0),
  ('rsp', 64, 4, 0), ('rbp', 64, 5, 0), ('rsi', 64, 6, 0), ('rdi', 64, 7, 0),
  ('r8', 64, 8, 1), ('r9', 64, 9, 1), ('r10', 64, 10, 1), ('r11', 64, 11, 1),
  ('r12', 64, 12, 1), ('r13', 64, 13, 1), ('r14', 64, 14, 1), ('r15', 64, 15, 1);

create table repo_asm_parametric_encoding_fact as
with binary_operand as (
  select match.path,
         match.repo_file_id,
         match.function_name,
         match.line_no,
         match.target_isa_id,
         match.op_name,
         match.operand_text,
         trim(substr(match.operand_text, 1, instr(match.operand_text, ',') - 1)) as lhs,
         trim(substr(match.operand_text, instr(match.operand_text, ',') + 1)) as rhs
  from repo_asm_rule_match match
  where match.target_isa_id = 1
    and match.line_kind = 3
    and match.encoding_id is null
    and match.rule_name is not null
    and instr(coalesce(match.operand_text, ''), ',') > 0
), normalized as (
  select *,
         case when lhs like 'byte %' then 'byte'
              when lhs like 'word %' then 'word'
              when lhs like 'dword %' then 'dword'
              when lhs like 'qword %' then 'qword'
              else null end as lhs_size,
         case when lhs like 'byte %' then trim(substr(lhs, 6))
              when lhs like 'word %' then trim(substr(lhs, 6))
              when lhs like 'dword %' then trim(substr(lhs, 7))
              when lhs like 'qword %' then trim(substr(lhs, 7))
              else lhs end as lhs_value,
         case when rhs like 'byte %' then 'byte'
              when rhs like 'word %' then 'word'
              when rhs like 'dword %' then 'dword'
              when rhs like 'qword %' then 'qword'
              else null end as rhs_size,
         case when rhs like 'byte %' then trim(substr(rhs, 6))
              when rhs like 'word %' then trim(substr(rhs, 6))
              when rhs like 'dword %' then trim(substr(rhs, 7))
              when rhs like 'qword %' then trim(substr(rhs, 7))
              else rhs end as rhs_value
  from binary_operand
), stack_memory as (
  select repo_file_id,
         function_name,
         line_no,
         side,
         size_name,
         memory_text,
         case
           when memory_text = '[rsp]' then 0
           when memory_text glob '[[]rsp + [0-9]*[]]'
             and substr(memory_text, 8, length(memory_text) - 8) not glob '*[^0-9]*'
             then cast(substr(memory_text, 8, length(memory_text) - 8) as integer)
         end as displacement
  from (
    select repo_file_id, function_name, line_no, 'lhs' as side, lhs_size as size_name, lhs_value as memory_text
    from normalized
    union all
    select repo_file_id, function_name, line_no, 'rhs' as side, rhs_size as size_name, rhs_value as memory_text
    from normalized
  )
  where memory_text = '[rsp]'
     or memory_text glob '[[]rsp + [0-9]*[]]'
), stack_memory_bytes as (
  select *,
         case
           when displacement = 0 then 0
           when displacement between -128 and 127 then 1
           else 2
         end as mod_bits,
         case
           when displacement = 0 then ''
           when displacement between -128 and 127 then printf('%02x', displacement & 255)
           else printf('%02x%02x%02x%02x',
                       displacement & 255,
                       (displacement >> 8) & 255,
                       (displacement >> 16) & 255,
                       (displacement >> 24) & 255)
         end as displacement_hex
  from stack_memory
  where displacement is not null
), base_memory as (
  select repo_file_id,
         function_name,
         line_no,
         side,
         size_name,
         memory_text,
         case
           when memory_text glob '[[][abcdefghijklmnopqrstuvwxyz0123456789]*[]]'
            and memory_text not like '%+%'
            and memory_text not like '%-%'
            and memory_text not like '%*%' then substr(memory_text, 2, length(memory_text) - 2)
           when memory_text glob '[[][abcdefghijklmnopqrstuvwxyz0123456789]* + [0-9]*[]]'
            and memory_text not like '%*%' then substr(memory_text, 2, instr(memory_text, ' + ') - 2)
         end as base_register_name,
         case
           when memory_text glob '[[][abcdefghijklmnopqrstuvwxyz0123456789]*[]]'
            and memory_text not like '%+%'
            and memory_text not like '%-%'
            and memory_text not like '%*%' then 0
           when memory_text glob '[[][abcdefghijklmnopqrstuvwxyz0123456789]* + [0-9]*[]]'
            and memory_text not like '%*%'
            and substr(memory_text, instr(memory_text, ' + ') + 3, length(memory_text) - instr(memory_text, ' + ') - 3) not glob '*[^0-9]*'
             then cast(substr(memory_text, instr(memory_text, ' + ') + 3, length(memory_text) - instr(memory_text, ' + ') - 3) as integer)
         end as displacement
  from (
    select repo_file_id, function_name, line_no, 'lhs' as side, lhs_size as size_name, lhs_value as memory_text
    from normalized
    union all
    select repo_file_id, function_name, line_no, 'rhs' as side, rhs_size as size_name, rhs_value as memory_text
    from normalized
  )
  where memory_text like '[%]'
    and memory_text not like '%rsp%'
), base_memory_bytes as (
  select base_memory.*,
         base_reg.reg_code as base_reg_code,
         base_reg.requires_rex as base_requires_rex,
         case
           when displacement = 0 and (base_reg.reg_code & 7) not in (5) then 0
           when displacement between -128 and 127 then 1
           else 2
         end as mod_bits,
         case
           when displacement = 0 and (base_reg.reg_code & 7) not in (5) then ''
           when displacement between -128 and 127 then printf('%02x', displacement & 255)
           else printf('%02x%02x%02x%02x',
                       displacement & 255,
                       (displacement >> 8) & 255,
                       (displacement >> 16) & 255,
                       (displacement >> 24) & 255)
         end as displacement_hex,
         case when (base_reg.reg_code & 7) = 4 then '24' else '' end as sib_hex,
         case when (base_reg.reg_code & 7) = 4 then 4 else (base_reg.reg_code & 7) end as rm_field
  from base_memory
  join x86_register_encoding_fact base_reg
    on base_reg.register_name = base_memory.base_register_name
   and base_reg.width_bits = 64
  where base_memory.displacement is not null
), reg_to_stack as (
  select normalized.*,
         reg.register_name,
         reg.width_bits,
         reg.reg_code,
         reg.requires_rex,
         mem.size_name,
         mem.mod_bits,
         mem.displacement_hex
  from normalized
  join x86_register_encoding_fact reg on reg.register_name = normalized.rhs_value
  join stack_memory_bytes mem
    on mem.repo_file_id = normalized.repo_file_id
   and mem.function_name = normalized.function_name
   and mem.line_no = normalized.line_no
   and mem.side = 'lhs'
  where normalized.op_name in ('mov','add','sub','cmp','and','or','xor')
    and reg.width_bits in (8,32,64)
    and (mem.size_name is null
         or (mem.size_name = 'byte' and reg.width_bits = 8)
         or (mem.size_name = 'dword' and reg.width_bits = 32)
         or (mem.size_name = 'qword' and reg.width_bits = 64))
), stack_to_reg as (
  select normalized.*,
         reg.register_name,
         reg.width_bits,
         reg.reg_code,
         reg.requires_rex,
         mem.size_name,
         mem.mod_bits,
         mem.displacement_hex
  from normalized
  join x86_register_encoding_fact reg on reg.register_name = normalized.lhs_value
  join stack_memory_bytes mem
    on mem.repo_file_id = normalized.repo_file_id
   and mem.function_name = normalized.function_name
   and mem.line_no = normalized.line_no
   and mem.side = 'rhs'
  where normalized.op_name in ('mov','add','sub','cmp','and','or','xor','lea')
    and reg.width_bits in (32,64)
    and (mem.size_name is null
         or (mem.size_name = 'dword' and reg.width_bits = 32)
         or (mem.size_name = 'qword' and reg.width_bits = 64))
), reg_to_base as (
  select normalized.*,
         reg.register_name,
         reg.width_bits,
         reg.reg_code,
         reg.requires_rex,
         mem.size_name,
         mem.base_reg_code,
         mem.base_requires_rex,
         mem.mod_bits,
         mem.rm_field,
         mem.sib_hex,
         mem.displacement_hex
  from normalized
  join x86_register_encoding_fact reg on reg.register_name = normalized.rhs_value
  join base_memory_bytes mem
    on mem.repo_file_id = normalized.repo_file_id
   and mem.function_name = normalized.function_name
   and mem.line_no = normalized.line_no
   and mem.side = 'lhs'
  where normalized.op_name in ('mov','add','sub','cmp','and','or','xor')
    and reg.width_bits in (8,32,64)
    and (mem.size_name is null
         or (mem.size_name = 'byte' and reg.width_bits = 8)
         or (mem.size_name = 'dword' and reg.width_bits = 32)
         or (mem.size_name = 'qword' and reg.width_bits = 64))
), base_to_reg as (
  select normalized.*,
         reg.register_name,
         reg.width_bits,
         reg.reg_code,
         reg.requires_rex,
         mem.size_name,
         mem.base_reg_code,
         mem.base_requires_rex,
         mem.mod_bits,
         mem.rm_field,
         mem.sib_hex,
         mem.displacement_hex
  from normalized
  join x86_register_encoding_fact reg on reg.register_name = normalized.lhs_value
  join base_memory_bytes mem
    on mem.repo_file_id = normalized.repo_file_id
   and mem.function_name = normalized.function_name
   and mem.line_no = normalized.line_no
   and mem.side = 'rhs'
  where normalized.op_name in ('mov','add','sub','cmp','and','or','xor','lea','movzx','movsx','movsxd')
    and reg.width_bits in (32,64)
    and (mem.size_name is null
         or (mem.size_name = 'byte' and normalized.op_name = 'movzx')
         or (mem.size_name = 'word' and normalized.op_name in ('movzx','movsx'))
         or (mem.size_name = 'dword' and reg.width_bits in (32,64))
         or (mem.size_name = 'qword' and reg.width_bits = 64))
), stack_imm as (
  select normalized.*,
         mem.size_name,
         mem.mod_bits,
         mem.displacement_hex
  from normalized
  join stack_memory_bytes mem
    on mem.repo_file_id = normalized.repo_file_id
   and mem.function_name = normalized.function_name
   and mem.line_no = normalized.line_no
   and mem.side = 'lhs'
  where normalized.rhs_value glob '[0-9]*'
    and normalized.rhs_value not glob '*[^0-9]*'
), reg_reg as (
  select normalized.*,
         dst.register_name as dst_register_name,
         dst.width_bits,
         dst.reg_code as dst_reg_code,
         dst.requires_rex as dst_requires_rex,
         src.register_name as src_register_name,
         src.reg_code as src_reg_code,
         src.requires_rex as src_requires_rex
  from normalized
  join x86_register_encoding_fact dst on dst.register_name = normalized.lhs_value
  join x86_register_encoding_fact src on src.register_name = normalized.rhs_value
  where normalized.op_name in ('mov','add','sub','cmp','and','or','xor','test')
    and dst.width_bits = src.width_bits
    and dst.width_bits in (8,32,64)
), movzx_reg_reg as (
  select normalized.*,
         dst.register_name as dst_register_name,
         dst.width_bits as dst_width_bits,
         dst.reg_code as dst_reg_code,
         dst.requires_rex as dst_requires_rex,
         src.register_name as src_register_name,
         src.width_bits as src_width_bits,
         src.reg_code as src_reg_code,
         src.requires_rex as src_requires_rex
  from normalized
  join x86_register_encoding_fact dst on dst.register_name = normalized.lhs_value
  join x86_register_encoding_fact src on src.register_name = normalized.rhs_value
  where normalized.op_name = 'movzx'
    and dst.width_bits in (32,64)
    and src.width_bits in (8,16)
), reg_imm as (
  select normalized.*,
         dst.register_name as dst_register_name,
         dst.width_bits,
         dst.reg_code as dst_reg_code,
         dst.requires_rex as dst_requires_rex,
         cast(normalized.rhs_value as integer) as immediate_value
  from normalized
  join x86_register_encoding_fact dst on dst.register_name = normalized.lhs_value
  where normalized.op_name in ('mov','add','sub','cmp','and','or','xor','shl','shr','sar','ror')
    and dst.width_bits in (32,64)
    and (normalized.rhs_value glob '[0-9]*'
         or normalized.rhs_value glob '-[0-9]*')
    and replace(normalized.rhs_value, '-', '') not glob '*[^0-9]*'
), unary_reg as (
  select repo_asm_rule_match.repo_file_id,
         repo_asm_rule_match.function_name,
         repo_asm_rule_match.line_no,
         repo_asm_rule_match.op_name,
         reg.register_name,
         reg.width_bits,
         reg.reg_code,
         reg.requires_rex
  from repo_asm_rule_match
  join x86_register_encoding_fact reg on reg.register_name = repo_asm_rule_match.operand_text
  where repo_asm_rule_match.target_isa_id = 1
    and repo_asm_rule_match.line_kind = 3
    and repo_asm_rule_match.encoding_id is null
    and repo_asm_rule_match.rule_name is not null
    and repo_asm_rule_match.op_name in ('inc','dec')
    and reg.width_bits in (32,64)
), generated as (
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_reg_reg' as parametric_rule_name,
         (
           case
             when width_bits = 64 then printf('%02x', 72 + case when src_reg_code >= 8 then 4 else 0 end + case when dst_reg_code >= 8 then 1 else 0 end)
             when src_requires_rex = 1 or dst_requires_rex = 1 then printf('%02x', 64 + case when src_reg_code >= 8 then 4 else 0 end + case when dst_reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || case op_name
                when 'mov' then case when width_bits = 8 then '88' else '89' end
                when 'add' then case when width_bits = 8 then '00' else '01' end
                when 'sub' then case when width_bits = 8 then '28' else '29' end
                when 'cmp' then case when width_bits = 8 then '38' else '39' end
                when 'and' then case when width_bits = 8 then '20' else '21' end
                when 'or' then case when width_bits = 8 then '08' else '09' end
                when 'xor' then case when width_bits = 8 then '30' else '31' end
                when 'test' then case when width_bits = 8 then '84' else '85' end
              end
           || printf('%02x', 192 + ((src_reg_code & 7) << 3) + (dst_reg_code & 7))
         ) as fixed_hex
  from reg_reg
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_movzx_reg_reg' as parametric_rule_name,
         (
           case
             when dst_width_bits = 64 then printf('%02x', 72 + case when dst_reg_code >= 8 then 4 else 0 end + case when src_reg_code >= 8 then 1 else 0 end)
             when dst_requires_rex = 1 or src_requires_rex = 1 then printf('%02x', 64 + case when dst_reg_code >= 8 then 4 else 0 end + case when src_reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || case src_width_bits
                when 8 then '0fb6'
                when 16 then '0fb7'
              end
           || printf('%02x', 192 + ((dst_reg_code & 7) << 3) + (src_reg_code & 7))
         ) as fixed_hex
  from movzx_reg_reg
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_mov_reg_imm32' as parametric_rule_name,
         (
           case
             when dst_requires_rex = 1 then printf('%02x', 64 + case when dst_reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || printf('%02x', 184 + (dst_reg_code & 7))
           || printf('%02x%02x%02x%02x',
                     immediate_value & 255,
                     (immediate_value >> 8) & 255,
                     (immediate_value >> 16) & 255,
                     (immediate_value >> 24) & 255)
         ) as fixed_hex
  from reg_imm
  where op_name = 'mov'
    and width_bits = 32
    and immediate_value between -2147483648 and 4294967295
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_reg_imm8' as parametric_rule_name,
         (
           case
             when width_bits = 64 then printf('%02x', 72 + case when dst_reg_code >= 8 then 1 else 0 end)
             when dst_requires_rex = 1 then printf('%02x', 64 + case when dst_reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || '83'
           || printf('%02x', 192 + ((case op_name
                                      when 'add' then 0
                                      when 'or' then 1
                                      when 'and' then 4
                                      when 'sub' then 5
                                      when 'xor' then 6
                                      when 'cmp' then 7
                                    end) << 3) + (dst_reg_code & 7))
           || printf('%02x', immediate_value & 255)
         ) as fixed_hex
  from reg_imm
  where op_name in ('add','sub','cmp','and','or','xor')
    and immediate_value between -128 and 127
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_reg_imm8' as parametric_rule_name,
         (
           case
             when width_bits = 64 then printf('%02x', 72 + case when dst_reg_code >= 8 then 1 else 0 end)
             when dst_requires_rex = 1 then printf('%02x', 64 + case when dst_reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || 'c1'
           || printf('%02x', 192 + ((case op_name
                                      when 'ror' then 1
                                      when 'shl' then 4
                                      when 'shr' then 5
                                      when 'sar' then 7
                                    end) << 3) + (dst_reg_code & 7))
           || printf('%02x', immediate_value & 255)
         ) as fixed_hex
  from reg_imm
  where op_name in ('shl','shr','sar','ror')
    and immediate_value between 0 and 255
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_reg' as parametric_rule_name,
         (
           case
             when width_bits = 64 then printf('%02x', 72 + case when reg_code >= 8 then 1 else 0 end)
             when requires_rex = 1 then printf('%02x', 64 + case when reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || 'ff'
           || printf('%02x', 192 + ((case op_name when 'inc' then 0 when 'dec' then 1 end) << 3) + (reg_code & 7))
         ) as fixed_hex
  from unary_reg
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_reg_base_memory' as parametric_rule_name,
         (
           case
             when op_name = 'movsxd' then printf('%02x', 72 + case when reg_code >= 8 then 4 else 0 end + case when base_reg_code >= 8 then 1 else 0 end)
             when width_bits = 64 then printf('%02x', 72 + case when reg_code >= 8 then 4 else 0 end + case when base_reg_code >= 8 then 1 else 0 end)
             when requires_rex = 1 or base_requires_rex = 1 then printf('%02x', 64 + case when reg_code >= 8 then 4 else 0 end + case when base_reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || case
                when op_name = 'movzx' and size_name = 'byte' then '0fb6'
                when op_name = 'movzx' and size_name = 'word' then '0fb7'
                when op_name = 'movsx' and size_name = 'word' then '0fbf'
                when op_name = 'movsxd' then '63'
                when op_name = 'mov' then '8b'
                when op_name = 'add' then '03'
                when op_name = 'sub' then '2b'
                when op_name = 'cmp' then '3b'
                when op_name = 'and' then '23'
                when op_name = 'or' then '0b'
                when op_name = 'xor' then '33'
                when op_name = 'lea' then '8d'
              end
           || printf('%02x', (mod_bits << 6) + ((reg_code & 7) << 3) + rm_field)
           || sib_hex
           || displacement_hex
         ) as fixed_hex
  from base_to_reg
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_base_memory_reg' as parametric_rule_name,
         (
           case
             when width_bits = 64 then printf('%02x', 72 + case when reg_code >= 8 then 4 else 0 end + case when base_reg_code >= 8 then 1 else 0 end)
             when requires_rex = 1 or base_requires_rex = 1 then printf('%02x', 64 + case when reg_code >= 8 then 4 else 0 end + case when base_reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || case
                when op_name = 'mov' and width_bits = 8 then '88'
                when op_name = 'mov' then '89'
                when op_name = 'add' then '01'
                when op_name = 'sub' then '29'
                when op_name = 'cmp' then '39'
                when op_name = 'and' then '21'
                when op_name = 'or' then '09'
                when op_name = 'xor' then '31'
              end
           || printf('%02x', (mod_bits << 6) + ((reg_code & 7) << 3) + rm_field)
           || sib_hex
           || displacement_hex
         ) as fixed_hex
  from reg_to_base
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_reg_stack' as parametric_rule_name,
         (
           case
             when width_bits = 64 then printf('%02x', 72 + case when reg_code >= 8 then 4 else 0 end)
             when requires_rex = 1 then printf('%02x', 64 + case when reg_code >= 8 then 4 else 0 end)
             else ''
           end
           || case op_name
                when 'mov' then '8b'
                when 'add' then '03'
                when 'sub' then '2b'
                when 'cmp' then '3b'
                when 'and' then '23'
                when 'or' then '0b'
                when 'xor' then '33'
                when 'lea' then '8d'
              end
           || printf('%02x', (mod_bits << 6) + ((reg_code & 7) << 3) + 4)
           || '24'
           || displacement_hex
         ) as fixed_hex
  from stack_to_reg
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_stack_reg' as parametric_rule_name,
         (
           case
             when width_bits = 64 then printf('%02x', 72 + case when reg_code >= 8 then 4 else 0 end)
             when requires_rex = 1 then printf('%02x', 64 + case when reg_code >= 8 then 4 else 0 end)
             else ''
           end
           || case
                when op_name = 'mov' and width_bits = 8 then '88'
                when op_name = 'mov' then '89'
                when op_name = 'add' then '01'
                when op_name = 'sub' then '29'
                when op_name = 'cmp' then '39'
                when op_name = 'and' then '21'
                when op_name = 'or' then '09'
                when op_name = 'xor' then '31'
              end
           || printf('%02x', (mod_bits << 6) + ((reg_code & 7) << 3) + 4)
           || '24'
           || displacement_hex
         ) as fixed_hex
  from reg_to_stack
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_dword_stack_imm8' as parametric_rule_name,
         (
           case op_name
             when 'cmp' then '83' || printf('%02x', (mod_bits << 6) + (7 << 3) + 4) || '24' || displacement_hex || printf('%02x', cast(rhs_value as integer) & 255)
             when 'add' then '83' || printf('%02x', (mod_bits << 6) + (0 << 3) + 4) || '24' || displacement_hex || printf('%02x', cast(rhs_value as integer) & 255)
             when 'sub' then '83' || printf('%02x', (mod_bits << 6) + (5 << 3) + 4) || '24' || displacement_hex || printf('%02x', cast(rhs_value as integer) & 255)
           end
         ) as fixed_hex
  from stack_imm
  where size_name = 'dword'
    and op_name in ('add','sub','cmp')
    and cast(rhs_value as integer) between -128 and 127
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_mov_dword_stack_imm32' as parametric_rule_name,
         (
           'c7' || printf('%02x', (mod_bits << 6) + 4) || '24' || displacement_hex
           || printf('%02x%02x%02x%02x',
                     cast(rhs_value as integer) & 255,
                     (cast(rhs_value as integer) >> 8) & 255,
                     (cast(rhs_value as integer) >> 16) & 255,
                     (cast(rhs_value as integer) >> 24) & 255)
         ) as fixed_hex
  from stack_imm
  where size_name = 'dword'
    and op_name = 'mov'
    and cast(rhs_value as integer) between 0 and 4294967295
  union all
  select normalized.repo_file_id,
         normalized.function_name,
         normalized.line_no,
         'param_x86_inc_dword_stack' as parametric_rule_name,
         'ff' || printf('%02x', (mod_bits << 6) + 4) || '24' || displacement_hex as fixed_hex
  from normalized
  join stack_memory_bytes mem
    on mem.repo_file_id = normalized.repo_file_id
   and mem.function_name = normalized.function_name
   and mem.line_no = normalized.line_no
   and mem.side = 'lhs'
  where normalized.op_name = 'inc'
    and mem.size_name = 'dword'
)
select generated.repo_file_id,
       generated.function_name,
       generated.line_no,
       generated.parametric_rule_name,
       generated.fixed_hex
from generated
where fixed_hex is not null;

create unique index repo_asm_parametric_encoding_fact_line_idx
  on repo_asm_parametric_encoding_fact(repo_file_id, function_name, line_no);

create view repo_asm_parametric_encoding_conflict as
select match.path,
       match.function_name,
       match.line_no,
       match.op_name,
       match.operand_text,
       match.fixed_hex as exact_hex,
       parametric.fixed_hex as parametric_hex,
       parametric.parametric_rule_name
from repo_asm_rule_match match
join repo_asm_parametric_encoding_fact parametric
  on parametric.repo_file_id = match.repo_file_id
 and parametric.function_name = match.function_name
 and parametric.line_no = match.line_no
where match.fixed_hex is not null
  and lower(match.fixed_hex) <> lower(parametric.fixed_hex);

create view repo_asm_constant_definition_fact as
select repo_file.path,
       operation.repo_file_id,
       operation.line_no,
       trim(operation.op_name) as symbol_name,
       trim(substr(operation.operand_text, 5)) as expression_text,
       'equ' as definition_kind
from repo_asm_operation operation
join repo_file using (repo_file_id)
where operation.line_kind = 5
  and operation.operand_text like 'equ %'
union all
select repo_file.path,
       operation.repo_file_id,
       operation.line_no,
       trim(substr(operation.operand_text, 1, instr(operation.operand_text, ' ') - 1)) as symbol_name,
       trim(substr(operation.operand_text, instr(operation.operand_text, ' ') + 1)) as expression_text,
       'define' as definition_kind
from repo_asm_operation operation
join repo_file using (repo_file_id)
where operation.op_name = '%define'
  and operation.operand_text like '% %'
union all
select repo_file.path,
       include_line.repo_file_id,
       include_line.line_no,
       trim(substr(t, 1, instr(t, ' equ ') - 1)) as symbol_name,
       trim(substr(t, instr(t, ' equ ') + 5)) as expression_text,
       'include_equ' as definition_kind
from (
  select repo_file_id,
         line_no,
         case
           when instr(trim(replace(text, char(9), ' ')), ';') > 0 then
             trim(substr(trim(replace(text, char(9), ' ')), 1, instr(trim(replace(text, char(9), ' ')), ';') - 1))
           else trim(replace(text, char(9), ' '))
         end as t
  from repo_asm_include_line
) include_line
join repo_file using (repo_file_id)
where t like '% equ %'
union all
select repo_file.path,
       include_line.repo_file_id,
       include_line.line_no,
       trim(substr(substr(t, 9), 1, instr(substr(t, 9), ' ') - 1)) as symbol_name,
       trim(substr(substr(t, 9), instr(substr(t, 9), ' ') + 1)) as expression_text,
       'include_define' as definition_kind
from (
  select repo_file_id,
         line_no,
         case
           when instr(trim(replace(text, char(9), ' ')), ';') > 0 then
             trim(substr(trim(replace(text, char(9), ' ')), 1, instr(trim(replace(text, char(9), ' ')), ';') - 1))
           else trim(replace(text, char(9), ' '))
         end as t
  from repo_asm_include_line
) include_line
join repo_file using (repo_file_id)
where t like '%define % %';

create table asm_constant_expression_symbol_fact (
  symbol_name text primary key,
  reason text not null
);

insert into asm_constant_expression_symbol_fact(symbol_name, reason) values
  ('ERROR_NO_SPACE', 'top known-gap error immediate'),
  ('ERROR_PARSE', 'top known-gap error immediate'),
  ('ERROR_BAD_ARGUMENT', 'top known-gap error immediate'),
  ('OBJECT_ERR_BAD_ARGUMENT', 'top known-gap object error immediate'),
  ('AV1_BLOCK_PIXELS_8X8', 'top known-gap AV1 size constant'),
  ('AV1_BLOCK_DIM_8', 'top known-gap AV1 size constant'),
  ('AV1_SEQ_MONO_CHROME', 'top known-gap AV1 structure offset'),
  ('TLS_GCM_BLOCK_LEN', 'top known-gap TLS size constant'),
  ('LOCAL_CELL_SIZE', 'top known-gap local transport size constant'),
  ('TOR_CELL_LEN', 'top known-gap Tor size constant'),
  ('TOR_RELAY_DATA', 'top known-gap Tor command constant'),
  ('HASH_SIZE', 'top known-gap hash size constant'),
  ('SYS_ioctl', 'top known-gap syscall constant'),
  ('SYS_mkdir', 'top known-gap syscall constant'),
  ('DIR_MODE_0755', 'top known-gap mode constant'),
  ('PCI_COMMAND', 'top known-gap PCI register constant'),
  ('SDHCI_INT_STATUS', 'top known-gap SDHCI register constant'),
  ('BL_SLOT_SIZE', 'top known-gap bootloader size constant'),
  ('TPM_ST_NO_SESSIONS', 'top known-gap TPM tag constant'),
  ('VP8_TEST_FRAME_WIDTH', 'top known-gap VP8 fixture constant'),
  ('VP8_FRAME_TAG_SIZE', 'top known-gap VP8 frame constant'),
  ('VP8_BOOL_READER_SIZE', 'top known-gap VP8 size constant'),
  ('VP8_CHROMA_BLOCK_SIZE', 'top known-gap VP8 size constant'),
  ('VP8_COEFF_BLOCK_COEFF_COUNT', 'top known-gap VP8 block constant'),
  ('VP8_COMPRESSED_HEADER_SIZE', 'top known-gap VP8 header constant'),
  ('VP8_DECODE_STACK_PAYLOAD', 'top known-gap VP8 stack offset'),
  ('VP8_DECODE_STACK_U_PLANE', 'top known-gap VP8 stack offset'),
  ('VP8_DECODE_STACK_V_PLANE', 'top known-gap VP8 stack offset'),
  ('VP8_DECODE_STACK_YUV', 'top known-gap VP8 stack offset'),
  ('VP8_DECODE_STACK_Y_PLANE', 'top known-gap VP8 stack offset'),
  ('VP8_DEQUANT_BLOCK_BYTES', 'top known-gap VP8 block constant'),
  ('VP8_KEY_FRAME_HEADER_SIZE', 'top known-gap VP8 header constant'),
  ('VP8_LOOP_FILTER_UPDATE_BITS', 'top known-gap VP8 bit-count constant'),
  ('VP8_MACROBLOCK_HEADER_SIZE', 'top known-gap VP8 header constant'),
  ('VP8_MACROBLOCK_PREDICTION_INTER_MOTION', 'top known-gap VP8 prediction constant'),
  ('VP8_MACROBLOCK_PREDICTION_INTER_SPLIT', 'top known-gap VP8 prediction constant'),
  ('VP8_MACROBLOCK_SIZE', 'top known-gap VP8 size constant'),
  ('VP8_MOTION_VECTOR_COL', 'top known-gap VP8 structure offset'),
  ('VP8_MOTION_VECTOR_ROW', 'top known-gap VP8 structure offset'),
  ('VP8_REFERENCE_COPY_GOLDEN', 'top known-gap VP8 reference constant'),
  ('VP8_REFERENCE_HEADER_SIZE', 'top known-gap VP8 header constant'),
  ('VP8_TEST_CHROMA_HEIGHT', 'top known-gap VP8 fixture constant'),
  ('VP8_TEST_CHROMA_WIDTH', 'top known-gap VP8 fixture constant'),
  ('VP8_TEST_FRAME_HEIGHT', 'top known-gap VP8 fixture constant'),
  ('VP8_TEST_FRAME_UV_BYTES', 'top known-gap VP8 fixture constant'),
  ('VP8_TEST_FRAME_Y_BYTES', 'top known-gap VP8 fixture constant'),
  ('VP8_TOKEN_PARTITION_ENTRY_SIZE', 'top known-gap VP8 table constant'),
  ('VP8_WHT_SHIFT', 'top known-gap VP8 shift constant'),
  ('VP8_YUV_ROUND', 'top known-gap VP8 round constant'),
  ('VP8_Y_BLOCK_COUNT', 'top known-gap VP8 block constant'),
  ('MP4_BOX_DESC_PAYLOAD_OFFSET', 'top known-gap MP4 structure offset'),
  ('MP4_BOX_DESC_PAYLOAD_LEN', 'top known-gap MP4 structure offset'),
  ('ST_STRUCT_SIZE', 'top known-gap Curve25519 structure size');

create table repo_asm_unique_constant_fact as
select definition.symbol_name,
       min(definition.expression_text) as expression_text,
       count(*) as definition_count
from repo_asm_constant_definition_fact definition
join asm_constant_expression_symbol_fact symbol using (symbol_name)
where definition.symbol_name <> ''
group by definition.symbol_name
having count(distinct definition.expression_text) = 1;

create unique index repo_asm_unique_constant_fact_symbol_idx on repo_asm_unique_constant_fact(symbol_name);

create table repo_asm_all_unique_constant_fact as
select definition.symbol_name,
       min(definition.expression_text) as expression_text,
       count(*) as definition_count
from repo_asm_constant_definition_fact definition
where definition.symbol_name <> ''
group by definition.symbol_name
having count(distinct definition.expression_text) = 1;

create unique index repo_asm_all_unique_constant_fact_symbol_idx on repo_asm_all_unique_constant_fact(symbol_name);

create table repo_asm_numeric_constant_value as
with recursive decimal_constant as (
  select symbol_name,
         cast(expression_text as integer) as immediate_value
  from repo_asm_all_unique_constant_fact
  where (expression_text glob '[0-9]*'
         or expression_text glob '-[0-9]*')
    and replace(expression_text, '-', '') not glob '*[^0-9]*'
), hex_constant_seed as (
  select symbol_name,
         substr(lower(expression_text), 3) as hex_text
  from repo_asm_all_unique_constant_fact
  where lower(expression_text) glob '0x[0-9a-f]*'
    and substr(lower(expression_text), 3) <> ''
    and substr(lower(expression_text), 3) not glob '*[^0-9a-f]*'
), hex_constant_parse(symbol_name, hex_text, digit_index, immediate_value) as (
  select symbol_name,
         hex_text,
         1 as digit_index,
         0 as immediate_value
  from hex_constant_seed
  union all
  select symbol_name,
         hex_text,
         digit_index + 1,
         (immediate_value * 16) + instr('0123456789abcdef', substr(hex_text, digit_index, 1)) - 1
  from hex_constant_parse
  where digit_index <= length(hex_text)
), hex_constant as (
  select symbol_name,
         immediate_value
  from hex_constant_parse
  where digit_index = length(hex_text) + 1
), octal_constant_seed as (
  select symbol_name,
         substr(lower(expression_text), 1, length(expression_text) - 1) as octal_text
  from repo_asm_all_unique_constant_fact
  where lower(expression_text) glob '[0-7]*o'
    and substr(lower(expression_text), 1, length(expression_text) - 1) <> ''
    and substr(lower(expression_text), 1, length(expression_text) - 1) not glob '*[^0-7]*'
), octal_constant_parse(symbol_name, octal_text, digit_index, immediate_value) as (
  select symbol_name,
         octal_text,
         1 as digit_index,
         0 as immediate_value
  from octal_constant_seed
  union all
  select symbol_name,
         octal_text,
         digit_index + 1,
         (immediate_value * 8) + instr('01234567', substr(octal_text, digit_index, 1)) - 1
  from octal_constant_parse
  where digit_index <= length(octal_text)
), octal_constant as (
  select symbol_name,
         immediate_value
  from octal_constant_parse
  where digit_index = length(octal_text) + 1
), value_0 as (
  select * from decimal_constant
  union all
  select * from hex_constant
  union all
  select * from octal_constant
), value_recursive(symbol_name, immediate_value) as (
  select symbol_name,
         immediate_value
  from value_0
  union
  select definition.symbol_name,
         lhs.immediate_value * rhs.immediate_value as immediate_value
  from repo_asm_all_unique_constant_fact definition
  join value_recursive lhs on lhs.symbol_name = trim(substr(definition.expression_text, 1, instr(definition.expression_text, ' * ') - 1))
  join value_0 rhs on rhs.symbol_name = trim(substr(definition.expression_text, instr(definition.expression_text, ' * ') + 3))
  where instr(definition.expression_text, ' * ') > 0
  union
  select definition.symbol_name,
         lhs.immediate_value * cast(trim(substr(definition.expression_text, instr(definition.expression_text, ' * ') + 3)) as integer)
  from repo_asm_all_unique_constant_fact definition
  join value_recursive lhs on lhs.symbol_name = trim(substr(definition.expression_text, 1, instr(definition.expression_text, ' * ') - 1))
  where instr(definition.expression_text, ' * ') > 0
    and trim(substr(definition.expression_text, instr(definition.expression_text, ' * ') + 3)) glob '[0-9]*'
    and trim(substr(definition.expression_text, instr(definition.expression_text, ' * ') + 3)) not glob '*[^0-9]*'
  union
  select definition.symbol_name,
         lhs.immediate_value + rhs.immediate_value
  from repo_asm_all_unique_constant_fact definition
  join value_recursive lhs on lhs.symbol_name = trim(substr(definition.expression_text, 1, instr(definition.expression_text, ' + ') - 1))
  join value_0 rhs on rhs.symbol_name = trim(substr(definition.expression_text, instr(definition.expression_text, ' + ') + 3))
  where instr(definition.expression_text, ' + ') > 0
  union
  select definition.symbol_name,
         lhs.immediate_value + cast(trim(substr(definition.expression_text, instr(definition.expression_text, ' + ') + 3)) as integer)
  from repo_asm_all_unique_constant_fact definition
  join value_recursive lhs on lhs.symbol_name = trim(substr(definition.expression_text, 1, instr(definition.expression_text, ' + ') - 1))
  where instr(definition.expression_text, ' + ') > 0
    and trim(substr(definition.expression_text, instr(definition.expression_text, ' + ') + 3)) glob '[0-9]*'
    and trim(substr(definition.expression_text, instr(definition.expression_text, ' + ') + 3)) not glob '*[^0-9]*'
  union
  select definition.symbol_name,
         lhs.immediate_value - rhs.immediate_value
  from repo_asm_all_unique_constant_fact definition
  join value_recursive lhs on lhs.symbol_name = trim(substr(definition.expression_text, 1, instr(definition.expression_text, ' - ') - 1))
  join value_0 rhs on rhs.symbol_name = trim(substr(definition.expression_text, instr(definition.expression_text, ' - ') + 3))
  where instr(definition.expression_text, ' - ') > 0
  union
  select definition.symbol_name,
         lhs.immediate_value - cast(trim(substr(definition.expression_text, instr(definition.expression_text, ' - ') + 3)) as integer)
  from repo_asm_all_unique_constant_fact definition
  join value_recursive lhs on lhs.symbol_name = trim(substr(definition.expression_text, 1, instr(definition.expression_text, ' - ') - 1))
  where instr(definition.expression_text, ' - ') > 0
    and trim(substr(definition.expression_text, instr(definition.expression_text, ' - ') + 3)) glob '[0-9]*'
    and trim(substr(definition.expression_text, instr(definition.expression_text, ' - ') + 3)) not glob '*[^0-9]*'
  union
  select definition.symbol_name,
         lhs.immediate_value + (rhs_lhs.immediate_value * rhs_rhs.immediate_value)
  from repo_asm_all_unique_constant_fact definition
  join value_recursive lhs on lhs.symbol_name = trim(substr(definition.expression_text, 1, instr(definition.expression_text, ' + ') - 1))
  join value_0 rhs_lhs on rhs_lhs.symbol_name = trim(substr(trim(substr(definition.expression_text, instr(definition.expression_text, ' + ') + 3)), 1, instr(trim(substr(definition.expression_text, instr(definition.expression_text, ' + ') + 3)), ' * ') - 1))
  join value_0 rhs_rhs on rhs_rhs.symbol_name = trim(substr(trim(substr(definition.expression_text, instr(definition.expression_text, ' + ') + 3)), instr(trim(substr(definition.expression_text, instr(definition.expression_text, ' + ') + 3)), ' * ') + 3))
  where instr(definition.expression_text, ' + ') > 0
    and instr(trim(substr(definition.expression_text, instr(definition.expression_text, ' + ') + 3)), ' * ') > 0
)
select symbol_name,
       min(immediate_value) as immediate_value
from value_recursive
group by symbol_name
having min(immediate_value) = max(immediate_value);

create unique index repo_asm_numeric_constant_value_symbol_idx on repo_asm_numeric_constant_value(symbol_name);

create table repo_asm_binary_operand_fact as
with binary_operand as (
  select match.path,
         match.repo_file_id,
         match.function_name,
         match.line_no,
         match.target_isa_id,
         match.op_name,
         match.operand_text,
         trim(substr(match.operand_text, 1, instr(match.operand_text, ',') - 1)) as lhs,
         trim(substr(match.operand_text, instr(match.operand_text, ',') + 1)) as rhs
  from repo_asm_rule_match match
  where match.line_kind = 3
    and instr(coalesce(match.operand_text, ''), ',') > 0
), normalized as (
  select *,
         case when lhs like 'byte %' then 'byte'
              when lhs like 'word %' then 'word'
              when lhs like 'dword %' then 'dword'
              when lhs like 'qword %' then 'qword'
              else null end as lhs_size,
         case when lhs like 'byte %' then trim(substr(lhs, 6))
              when lhs like 'word %' then trim(substr(lhs, 6))
              when lhs like 'dword %' then trim(substr(lhs, 7))
              when lhs like 'qword %' then trim(substr(lhs, 7))
              else lhs end as lhs_value,
         case when rhs like 'byte %' then 'byte'
              when rhs like 'word %' then 'word'
              when rhs like 'dword %' then 'dword'
              when rhs like 'qword %' then 'qword'
              else null end as rhs_size,
         case when rhs like 'byte %' then trim(substr(rhs, 6))
              when rhs like 'word %' then trim(substr(rhs, 6))
              when rhs like 'dword %' then trim(substr(rhs, 7))
              when rhs like 'qword %' then trim(substr(rhs, 7))
              else rhs end as rhs_value
  from binary_operand
), operand_rows as (
  select path,
         repo_file_id,
         function_name,
         line_no,
         target_isa_id,
         op_name,
         operand_text,
         0 as operand_index,
         lhs_size as size_name,
         lhs_value as operand_value
  from normalized
  union all
  select path,
         repo_file_id,
         function_name,
         line_no,
         target_isa_id,
         op_name,
         operand_text,
         1 as operand_index,
         rhs_size as size_name,
         rhs_value as operand_value
  from normalized
)
select operand_rows.*,
       case
         when operand_value like '[%]' then 'memory'
         when reg.register_name is not null then 'register'
         when (operand_value glob '[0-9]*' or operand_value glob '-[0-9]*')
          and replace(operand_value, '-', '') not glob '*[^0-9]*' then 'integer'
         when lower(operand_value) glob '0x[0-9a-f]*' then 'integer'
         when operand_value glob '[ABCDEFGHIJKLMNOPQRSTUVWXYZ_]*'
          and operand_value not glob '*[^ABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789]*' then 'symbol'
         else 'other'
       end as operand_kind
from operand_rows
left join x86_register_encoding_fact reg
  on reg.register_name = operand_rows.operand_value;

create index repo_asm_binary_operand_fact_line_idx
  on repo_asm_binary_operand_fact(repo_file_id, function_name, line_no, operand_index);
create index repo_asm_binary_operand_fact_kind_idx
  on repo_asm_binary_operand_fact(operand_kind, target_isa_id, op_name);

create table repo_asm_memory_operand_fact as
select path,
       repo_file_id,
       function_name,
       line_no,
       target_isa_id,
       op_name,
       operand_text,
       operand_index,
       size_name,
       operand_value as memory_text,
       substr(operand_value, 2, length(operand_value) - 2) as inner_text,
       case when operand_value like '[rel %]' then 1 else 0 end as is_rel_memory
from repo_asm_binary_operand_fact
where operand_kind = 'memory';

create index repo_asm_memory_operand_fact_line_idx
  on repo_asm_memory_operand_fact(repo_file_id, function_name, line_no, operand_index);
create index repo_asm_memory_operand_fact_rel_idx
  on repo_asm_memory_operand_fact(is_rel_memory, target_isa_id, op_name);

create table repo_asm_memory_operand_term_fact as
with recursive memory_terms as (
  select path,
         repo_file_id,
         function_name,
         line_no,
         target_isa_id,
         op_name,
         operand_text,
         operand_index,
         size_name,
         memory_text,
         is_rel_memory,
         0 as term_index,
         trim(replace(inner_text, ' - ', ' + -')) || ' + ' as remaining_text,
         '' as term_text
  from repo_asm_memory_operand_fact
  union all
  select path,
         repo_file_id,
         function_name,
         line_no,
         target_isa_id,
         op_name,
         operand_text,
         operand_index,
         size_name,
         memory_text,
         is_rel_memory,
         term_index + 1,
         ltrim(substr(remaining_text, instr(remaining_text, ' + ') + 3)) as remaining_text,
         trim(substr(remaining_text, 1, instr(remaining_text, ' + ') - 1)) as term_text
  from memory_terms
  where remaining_text <> ''
    and instr(remaining_text, ' + ') > 0
)
select memory_terms.path,
       memory_terms.repo_file_id,
       memory_terms.function_name,
       memory_terms.line_no,
       memory_terms.target_isa_id,
       memory_terms.op_name,
       memory_terms.operand_text,
       memory_terms.operand_index,
       memory_terms.size_name,
       memory_terms.memory_text,
       memory_terms.is_rel_memory,
       memory_terms.term_index,
       case when memory_terms.term_text like '-%' then -1 else 1 end as term_sign,
       case when memory_terms.term_text like '-%' then substr(memory_terms.term_text, 2) else memory_terms.term_text end as term_text,
       case
         when memory_terms.term_text = 'rel' then 'rel_marker'
         when reg.register_name is not null then 'register'
         when scale_reg.register_name is not null then 'scaled_register'
         when (case when memory_terms.term_text like '-%' then substr(memory_terms.term_text, 2) else memory_terms.term_text end) glob '[0-9]*'
          and (case when memory_terms.term_text like '-%' then substr(memory_terms.term_text, 2) else memory_terms.term_text end) not glob '*[^0-9]*' then 'integer'
         when (case when memory_terms.term_text like '-%' then substr(memory_terms.term_text, 2) else memory_terms.term_text end) glob '[ABCDEFGHIJKLMNOPQRSTUVWXYZ_]*'
          and (case when memory_terms.term_text like '-%' then substr(memory_terms.term_text, 2) else memory_terms.term_text end) not glob '*[^ABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789]*' then 'symbol'
         else 'other'
       end as term_kind,
       scale_reg.register_name as scale_register_name,
       case
         when scale_reg.register_name is not null
          and trim(substr((case when memory_terms.term_text like '-%' then substr(memory_terms.term_text, 2) else memory_terms.term_text end),
                          instr((case when memory_terms.term_text like '-%' then substr(memory_terms.term_text, 2) else memory_terms.term_text end), '*') + 1)) in ('1','2','4','8')
           then cast(trim(substr((case when memory_terms.term_text like '-%' then substr(memory_terms.term_text, 2) else memory_terms.term_text end),
                                  instr((case when memory_terms.term_text like '-%' then substr(memory_terms.term_text, 2) else memory_terms.term_text end), '*') + 1)) as integer)
       end as scale_value
from memory_terms
left join x86_register_encoding_fact reg
  on reg.register_name = (case when memory_terms.term_text like '-%' then substr(memory_terms.term_text, 2) else memory_terms.term_text end)
left join x86_register_encoding_fact scale_reg
  on scale_reg.register_name = trim(substr((case when memory_terms.term_text like '-%' then substr(memory_terms.term_text, 2) else memory_terms.term_text end),
                                           1,
                                           instr((case when memory_terms.term_text like '-%' then substr(memory_terms.term_text, 2) else memory_terms.term_text end), '*') - 1))
 and instr((case when memory_terms.term_text like '-%' then substr(memory_terms.term_text, 2) else memory_terms.term_text end), '*') > 0
where memory_terms.term_text <> '';

create index repo_asm_memory_operand_term_fact_line_idx
  on repo_asm_memory_operand_term_fact(repo_file_id, function_name, line_no, operand_index, term_index);
create index repo_asm_memory_operand_term_fact_kind_idx
  on repo_asm_memory_operand_term_fact(term_kind, target_isa_id, op_name);
create index repo_asm_memory_operand_term_fact_symbol_idx
  on repo_asm_memory_operand_term_fact(term_kind, term_text, repo_file_id, function_name, line_no, operand_index);

create table repo_asm_memory_addressing_fact as
select memory.path,
       memory.repo_file_id,
       memory.function_name,
       memory.line_no,
       memory.target_isa_id,
       memory.op_name,
       memory.operand_text,
       memory.operand_index,
       memory.size_name,
       memory.memory_text,
       memory.is_rel_memory,
       sum(case when term.term_kind = 'register' then 1 else 0 end) as register_term_count,
       sum(case when term.term_kind = 'scaled_register' then 1 else 0 end) as scaled_register_term_count,
       sum(case when term.term_kind = 'symbol' then 1 else 0 end) as symbol_term_count,
       sum(case when term.term_kind = 'integer' then 1 else 0 end) as integer_term_count,
       sum(case when term.term_kind = 'rel_marker' then 1 else 0 end) as rel_marker_count,
       min(case when term.term_kind = 'register' then term.term_text end) as first_register_term,
       min(case when term.term_kind = 'scaled_register' then term.scale_register_name end) as first_scaled_register_term,
       min(case when term.term_kind = 'scaled_register' then term.scale_value end) as first_scale_value,
       min(case when term.term_kind = 'symbol' then term.term_text end) as first_symbol_term,
       sum(case when term.term_kind = 'integer' then term.term_sign * cast(term.term_text as integer) else 0 end) as integer_displacement,
       case
         when memory.is_rel_memory = 1 then 'rel_memory'
         when sum(case when term.term_kind = 'scaled_register' then 1 else 0 end) > 0 then 'indexed_memory'
         when sum(case when term.term_kind = 'register' then 1 else 0 end) >= 2 then 'indexed_memory'
         when sum(case when term.term_kind = 'symbol' then 1 else 0 end) > 0 then 'symbolic_base_memory'
         when sum(case when term.term_kind = 'register' then 1 else 0 end) = 1 then 'base_memory'
         else 'other_memory'
       end as addressing_kind
from repo_asm_memory_operand_fact memory
left join repo_asm_memory_operand_term_fact term
  on term.repo_file_id = memory.repo_file_id
 and term.function_name = memory.function_name
 and term.line_no = memory.line_no
 and term.operand_index = memory.operand_index
group by memory.path,
         memory.repo_file_id,
         memory.function_name,
         memory.line_no,
         memory.target_isa_id,
         memory.op_name,
         memory.operand_text,
         memory.operand_index,
         memory.size_name,
         memory.memory_text,
         memory.is_rel_memory;

create index repo_asm_memory_addressing_fact_line_idx
  on repo_asm_memory_addressing_fact(repo_file_id, function_name, line_no, operand_index);
create index repo_asm_memory_addressing_fact_kind_idx
  on repo_asm_memory_addressing_fact(addressing_kind, target_isa_id, op_name);

create table repo_asm_constant_candidate_operation as
select *
from repo_asm_operation
where line_kind = 3
  and operand_text is not null
  and operand_text glob '*[ABCDEFGHIJKLMNOPQRSTUVWXYZ_]*';

create index repo_asm_constant_candidate_operation_operand_idx
  on repo_asm_constant_candidate_operation(operand_text);

create table repo_asm_constant_candidate_operand_text as
select path,
       repo_file_id,
       function_name,
       line_no,
       op_name,
       operand_text,
       ' ' || replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(operand_text,
         ',', ' '), '[', ' '), ']', ' '), '+', ' '), '-', ' '), '*', ' '), '/', ' '), '(', ' '), ')', ' '), ':', ' ') || ' ' as normalized_operand_text
from repo_asm_constant_candidate_operation;

create index repo_asm_constant_candidate_operand_text_line_idx
  on repo_asm_constant_candidate_operand_text(repo_file_id, function_name, line_no);

create table repo_asm_constant_candidate_operand_token as
with recursive token_rows as (
  select path,
         repo_file_id,
         function_name,
         line_no,
         op_name,
         operand_text,
         ltrim(normalized_operand_text) as remaining_text,
         '' as token_text
  from repo_asm_constant_candidate_operand_text
  union all
  select path,
         repo_file_id,
         function_name,
         line_no,
         op_name,
         operand_text,
         ltrim(substr(remaining_text, instr(remaining_text, ' ') + 1)) as remaining_text,
         trim(substr(remaining_text, 1, instr(remaining_text, ' ') - 1)) as token_text
  from token_rows
  where instr(remaining_text, ' ') > 0
)
select path,
       repo_file_id,
       function_name,
       line_no,
       op_name,
       operand_text,
       token_text
from token_rows
where token_text <> '';

create index repo_asm_constant_candidate_operand_token_idx
  on repo_asm_constant_candidate_operand_token(token_text, repo_file_id, function_name, line_no);

create table repo_asm_constant_operand_symbol_match as
select token.path,
       token.repo_file_id,
       token.function_name,
       token.line_no,
       token.op_name,
       token.operand_text,
       symbol.symbol_name
from repo_asm_constant_candidate_operand_token token
join asm_constant_expression_symbol_fact symbol
  on symbol.symbol_name = token.token_text
union
select token.path,
       token.repo_file_id,
       token.function_name,
       token.line_no,
       token.op_name,
       token.operand_text,
       constant.symbol_name
from repo_asm_constant_candidate_operand_token token
join repo_asm_all_unique_constant_fact constant
  on constant.symbol_name = token.token_text
where length(constant.symbol_name) >= 2
  and constant.symbol_name not like '%:%'
  and substr(constant.symbol_name, 1, 1) <> '%'
  and constant.symbol_name not glob '*[^A-Za-z0-9_.$]*';

create index repo_asm_constant_operand_symbol_match_symbol_idx
  on repo_asm_constant_operand_symbol_match(symbol_name);
create index repo_asm_constant_operand_symbol_match_line_idx
  on repo_asm_constant_operand_symbol_match(repo_file_id, function_name, line_no, symbol_name);

create table repo_asm_scoped_constant_expression_match as
select match.path,
       match.repo_file_id,
       match.function_name,
       match.line_no,
       match.op_name,
       match.operand_text,
       match.symbol_name,
       min(definition.expression_text) as expression_text
from repo_asm_constant_operand_symbol_match match
join repo_asm_constant_definition_fact definition
  on definition.symbol_name = match.symbol_name
 and (definition.path = match.path
      or exists (select 1
                 from repo_asm_include_closure_fact include_closure
                 where include_closure.source_path = match.path
                   and include_closure.target_path = definition.path))
group by match.path,
         match.repo_file_id,
         match.function_name,
         match.line_no,
         match.op_name,
         match.operand_text,
         match.symbol_name
having count(distinct definition.expression_text) = 1;

create index repo_asm_scoped_constant_expression_match_line_idx
  on repo_asm_scoped_constant_expression_match(repo_file_id, function_name, line_no, symbol_name);

create table repo_asm_global_constant_expression_match as
select match.path,
       match.repo_file_id,
       match.function_name,
       match.line_no,
       match.op_name,
       match.operand_text,
       constant.symbol_name,
       constant.expression_text
from repo_asm_constant_operand_symbol_match match
join repo_asm_all_unique_constant_fact constant
  on constant.symbol_name = match.symbol_name
where not exists (select 1
                  from repo_asm_scoped_constant_expression_match scoped
                  where scoped.repo_file_id = match.repo_file_id
                    and scoped.function_name = match.function_name
                    and scoped.line_no = match.line_no
                    and scoped.symbol_name = constant.symbol_name);

create index repo_asm_global_constant_expression_match_line_idx
  on repo_asm_global_constant_expression_match(repo_file_id, function_name, line_no, symbol_name);

create table repo_asm_constant_expression_fact as
select path,
       repo_file_id,
       function_name,
       line_no,
       op_name,
       operand_text,
       min(symbol_name) as symbol_name,
       min(expression_text) as expression_text,
       count(distinct symbol_name) as symbol_count
from (
  select * from repo_asm_scoped_constant_expression_match
  union all
  select * from repo_asm_global_constant_expression_match
)
group by path,
         repo_file_id,
         function_name,
         line_no,
         op_name,
         operand_text;

create index repo_asm_constant_expression_fact_line_idx on repo_asm_constant_expression_fact(repo_file_id, function_name, line_no);

create table repo_asm_symbolic_parametric_encoding_fact as
with recursive binary_operand as (
  select match.path,
         match.repo_file_id,
         match.function_name,
         match.line_no,
         match.target_isa_id,
         match.op_name,
         match.operand_text,
         trim(substr(match.operand_text, 1, instr(match.operand_text, ',') - 1)) as lhs,
         trim(substr(match.operand_text, instr(match.operand_text, ',') + 1)) as rhs,
         constant_expr.symbol_name,
         trim(constant_expr.expression_text) as expression_text
  from repo_asm_rule_match match
  join repo_asm_constant_expression_fact constant_expr
    on constant_expr.repo_file_id = match.repo_file_id
   and constant_expr.function_name = match.function_name
   and constant_expr.line_no = match.line_no
  where match.target_isa_id = 1
    and match.line_kind = 3
    and match.encoding_id is null
    and match.rule_name is not null
    and constant_expr.symbol_count = 1
    and instr(coalesce(match.operand_text, ''), ',') > 0
), decimal_line_constant as (
  select repo_file_id,
         function_name,
         line_no,
         cast(expression_text as integer) as immediate_value
  from binary_operand
  where (expression_text glob '[0-9]*'
         or expression_text glob '-[0-9]*')
    and replace(expression_text, '-', '') not glob '*[^0-9]*'
), hex_line_constant_seed as (
  select repo_file_id,
         function_name,
         line_no,
         substr(lower(expression_text), 3) as hex_text
  from binary_operand
  where lower(expression_text) glob '0x[0-9a-f]*'
    and substr(lower(expression_text), 3) <> ''
    and substr(lower(expression_text), 3) not glob '*[^0-9a-f]*'
), hex_line_constant_parse(repo_file_id, function_name, line_no, hex_text, digit_index, immediate_value) as (
  select repo_file_id,
         function_name,
         line_no,
         hex_text,
         1 as digit_index,
         0 as immediate_value
  from hex_line_constant_seed
  union all
  select repo_file_id,
         function_name,
         line_no,
         hex_text,
         digit_index + 1,
         (immediate_value * 16) + instr('0123456789abcdef', substr(hex_text, digit_index, 1)) - 1
  from hex_line_constant_parse
  where digit_index <= length(hex_text)
), hex_line_constant as (
  select repo_file_id,
         function_name,
         line_no,
         immediate_value
  from hex_line_constant_parse
  where digit_index = length(hex_text) + 1
), octal_line_constant_seed as (
  select repo_file_id,
         function_name,
         line_no,
         substr(lower(expression_text), 1, length(expression_text) - 1) as octal_text
  from binary_operand
  where lower(expression_text) glob '[0-7]*o'
    and substr(lower(expression_text), 1, length(expression_text) - 1) <> ''
    and substr(lower(expression_text), 1, length(expression_text) - 1) not glob '*[^0-7]*'
), octal_line_constant_parse(repo_file_id, function_name, line_no, octal_text, digit_index, immediate_value) as (
  select repo_file_id,
         function_name,
         line_no,
         octal_text,
         1 as digit_index,
         0 as immediate_value
  from octal_line_constant_seed
  union all
  select repo_file_id,
         function_name,
         line_no,
         octal_text,
         digit_index + 1,
         (immediate_value * 8) + instr('01234567', substr(octal_text, digit_index, 1)) - 1
  from octal_line_constant_parse
  where digit_index <= length(octal_text)
), octal_line_constant as (
  select repo_file_id,
         function_name,
         line_no,
         immediate_value
  from octal_line_constant_parse
  where digit_index = length(octal_text) + 1
), symbol_constant as (
  select binary_operand.repo_file_id,
         binary_operand.function_name,
         binary_operand.line_no,
         constant_value.immediate_value
  from binary_operand
  join repo_asm_numeric_constant_value constant_value
    on constant_value.symbol_name = binary_operand.symbol_name
), line_constant as (
  select * from decimal_line_constant
  union all
  select * from hex_line_constant
  union all
  select * from octal_line_constant
  union all
  select * from symbol_constant
), constant_value as (
  select repo_file_id,
         function_name,
         line_no,
         min(immediate_value) as immediate_value
  from line_constant
  group by repo_file_id, function_name, line_no
  having min(immediate_value) = max(immediate_value)
), numeric_constant as (
  select binary_operand.*,
         constant_value.immediate_value
  from binary_operand
  join constant_value
    on constant_value.repo_file_id = binary_operand.repo_file_id
   and constant_value.function_name = binary_operand.function_name
   and constant_value.line_no = binary_operand.line_no
), normalized as (
  select *,
         case when lhs like 'byte %' then 'byte'
              when lhs like 'word %' then 'word'
              when lhs like 'dword %' then 'dword'
              when lhs like 'qword %' then 'qword'
              else null end as lhs_size,
         case when lhs like 'byte %' then trim(substr(lhs, 6))
              when lhs like 'word %' then trim(substr(lhs, 6))
              when lhs like 'dword %' then trim(substr(lhs, 7))
              when lhs like 'qword %' then trim(substr(lhs, 7))
              else lhs end as lhs_value,
         case when rhs like 'byte %' then 'byte'
              when rhs like 'word %' then 'word'
              when rhs like 'dword %' then 'dword'
              when rhs like 'qword %' then 'qword'
              else null end as rhs_size,
         case when rhs like 'byte %' then trim(substr(rhs, 6))
              when rhs like 'word %' then trim(substr(rhs, 6))
              when rhs like 'dword %' then trim(substr(rhs, 7))
              when rhs like 'qword %' then trim(substr(rhs, 7))
              else rhs end as rhs_value
  from numeric_constant
), stack_memory as (
  select repo_file_id,
         function_name,
         line_no,
         side,
         size_name,
         memory_text,
         case
           when memory_text = '[rsp]' then 0
           when memory_text glob '[[]rsp + [0-9]*[]]'
             and substr(memory_text, 8, length(memory_text) - 8) not glob '*[^0-9]*'
             then cast(substr(memory_text, 8, length(memory_text) - 8) as integer)
         end as displacement
  from (
    select repo_file_id, function_name, line_no, 'lhs' as side, lhs_size as size_name, lhs_value as memory_text
    from normalized
  )
  where memory_text = '[rsp]'
     or memory_text glob '[[]rsp + [0-9]*[]]'
), stack_memory_bytes as (
  select *,
         case
           when displacement = 0 then 0
           when displacement between -128 and 127 then 1
           else 2
         end as mod_bits,
         case
           when displacement = 0 then ''
           when displacement between -128 and 127 then printf('%02x', displacement & 255)
           else printf('%02x%02x%02x%02x',
                       displacement & 255,
                       (displacement >> 8) & 255,
                       (displacement >> 16) & 255,
                       (displacement >> 24) & 255)
         end as displacement_hex
  from stack_memory
  where displacement is not null
), base_symbol_memory as (
  select repo_file_id,
         function_name,
         line_no,
         side,
         size_name,
         memory_text,
         symbol_name,
         immediate_value,
         trim(substr(substr(memory_text, 2, length(memory_text) - 2), 1, instr(substr(memory_text, 2, length(memory_text) - 2), ' + ') - 1)) as base_register_name,
         trim(substr(substr(memory_text, 2, length(memory_text) - 2), instr(substr(memory_text, 2, length(memory_text) - 2), ' + ') + 3)) as displacement_text
  from (
    select repo_file_id, function_name, line_no, 'lhs' as side, lhs_size as size_name, lhs_value as memory_text, symbol_name, immediate_value
    from normalized
    union all
    select repo_file_id, function_name, line_no, 'rhs' as side, rhs_size as size_name, rhs_value as memory_text, symbol_name, immediate_value
    from normalized
  )
  where memory_text like '[% + %]'
    and memory_text not like '[rel %'
    and memory_text not like '%*%'
), base_symbol_memory_decoded as (
  select *,
         case
           when displacement_text = symbol_name then immediate_value
           when displacement_text glob symbol_name || ' + [0-9]*'
            and trim(substr(displacement_text, length(symbol_name) + 4)) not glob '*[^0-9]*'
             then immediate_value + cast(trim(substr(displacement_text, length(symbol_name) + 4)) as integer)
           when displacement_text glob symbol_name || ' - [0-9]*'
            and trim(substr(displacement_text, length(symbol_name) + 4)) not glob '*[^0-9]*'
             then immediate_value - cast(trim(substr(displacement_text, length(symbol_name) + 4)) as integer)
         end as displacement
  from base_symbol_memory
), base_symbol_memory_bytes as (
  select base_symbol_memory_decoded.*,
         base_reg.reg_code as base_reg_code,
         base_reg.requires_rex as base_requires_rex,
         case
           when displacement = 0 and (base_reg.reg_code & 7) not in (5) then 0
           when displacement between -128 and 127 then 1
           else 2
         end as mod_bits,
         case
           when displacement = 0 and (base_reg.reg_code & 7) not in (5) then ''
           when displacement between -128 and 127 then printf('%02x', displacement & 255)
           else printf('%02x%02x%02x%02x',
                       displacement & 255,
                       (displacement >> 8) & 255,
                       (displacement >> 16) & 255,
                       (displacement >> 24) & 255)
         end as displacement_hex,
         case when (base_reg.reg_code & 7) = 4 then '24' else '' end as sib_hex,
         case when (base_reg.reg_code & 7) = 4 then 4 else (base_reg.reg_code & 7) end as rm_field
  from base_symbol_memory_decoded
  join x86_register_encoding_fact base_reg
    on base_reg.register_name = base_symbol_memory_decoded.base_register_name
   and base_reg.width_bits = 64
  where base_symbol_memory_decoded.displacement is not null
), reg_imm as (
  select normalized.*,
         dst.register_name as dst_register_name,
         dst.width_bits,
         dst.reg_code as dst_reg_code,
         dst.requires_rex as dst_requires_rex
  from normalized
  join x86_register_encoding_fact dst on dst.register_name = normalized.lhs_value
  where normalized.rhs_value = normalized.symbol_name
    and normalized.op_name in ('mov','add','sub','cmp','and','or','xor','shl','shr','sar','ror')
    and dst.width_bits in (32,64)
), reg_to_base_symbol as (
  select normalized.*,
         reg.register_name,
         reg.width_bits,
         reg.reg_code,
         reg.requires_rex,
         mem.size_name,
         mem.base_reg_code,
         mem.base_requires_rex,
         mem.mod_bits,
         mem.rm_field,
         mem.sib_hex,
         mem.displacement_hex
  from normalized
  join x86_register_encoding_fact reg on reg.register_name = normalized.rhs_value
  join base_symbol_memory_bytes mem
    on mem.repo_file_id = normalized.repo_file_id
   and mem.function_name = normalized.function_name
   and mem.line_no = normalized.line_no
   and mem.side = 'lhs'
  where normalized.op_name in ('mov','add','sub','cmp','and','or','xor')
    and reg.width_bits in (8,32,64)
    and (mem.size_name is null
         or (mem.size_name = 'byte' and reg.width_bits = 8)
         or (mem.size_name = 'dword' and reg.width_bits = 32)
         or (mem.size_name = 'qword' and reg.width_bits = 64))
), base_symbol_to_reg as (
  select normalized.*,
         reg.register_name,
         reg.width_bits,
         reg.reg_code,
         reg.requires_rex,
         mem.size_name,
         mem.base_reg_code,
         mem.base_requires_rex,
         mem.mod_bits,
         mem.rm_field,
         mem.sib_hex,
         mem.displacement_hex
  from normalized
  join x86_register_encoding_fact reg on reg.register_name = normalized.lhs_value
  join base_symbol_memory_bytes mem
    on mem.repo_file_id = normalized.repo_file_id
   and mem.function_name = normalized.function_name
   and mem.line_no = normalized.line_no
   and mem.side = 'rhs'
  where normalized.op_name in ('mov','add','sub','cmp','and','or','xor','lea','movzx','movsx','movsxd')
    and reg.width_bits in (32,64)
    and (mem.size_name is null
         or (mem.size_name = 'byte' and normalized.op_name = 'movzx')
         or (mem.size_name = 'word' and normalized.op_name in ('movzx','movsx'))
         or (mem.size_name = 'dword' and reg.width_bits in (32,64))
         or (mem.size_name = 'qword' and reg.width_bits = 64))
), base_symbol_imm as (
  select normalized.*,
         mem.size_name,
         mem.base_reg_code,
         mem.base_requires_rex,
         mem.mod_bits,
         mem.rm_field,
         mem.sib_hex,
         mem.displacement_hex,
         cast(normalized.rhs_value as integer) as rhs_immediate_value
  from normalized
  join base_symbol_memory_bytes mem
    on mem.repo_file_id = normalized.repo_file_id
   and mem.function_name = normalized.function_name
   and mem.line_no = normalized.line_no
   and mem.side = 'lhs'
  where normalized.op_name in ('mov','add','sub','cmp')
    and (normalized.rhs_value glob '[0-9]*'
         or normalized.rhs_value glob '-[0-9]*')
    and replace(normalized.rhs_value, '-', '') not glob '*[^0-9]*'
    and mem.size_name in ('byte','dword','qword')
), stack_imm as (
  select normalized.*,
         mem.size_name,
         mem.mod_bits,
         mem.displacement_hex
  from normalized
  join stack_memory_bytes mem
    on mem.repo_file_id = normalized.repo_file_id
   and mem.function_name = normalized.function_name
   and mem.line_no = normalized.line_no
   and mem.side = 'lhs'
  where normalized.rhs_value = normalized.symbol_name
), generated as (
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_mov_reg_symbol_imm32' as parametric_rule_name,
         (
           case
             when dst_requires_rex = 1 then printf('%02x', 64 + case when dst_reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || printf('%02x', 184 + (dst_reg_code & 7))
           || printf('%02x%02x%02x%02x',
                     immediate_value & 255,
                     (immediate_value >> 8) & 255,
                     (immediate_value >> 16) & 255,
                     (immediate_value >> 24) & 255)
         ) as fixed_hex
  from reg_imm
  where op_name = 'mov'
    and width_bits = 32
    and immediate_value between -2147483648 and 4294967295
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_reg_symbol_imm8' as parametric_rule_name,
         (
           case
             when width_bits = 64 then printf('%02x', 72 + case when dst_reg_code >= 8 then 1 else 0 end)
             when dst_requires_rex = 1 then printf('%02x', 64 + case when dst_reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || '83'
           || printf('%02x', 192 + ((case op_name
                                      when 'add' then 0
                                      when 'or' then 1
                                      when 'and' then 4
                                      when 'sub' then 5
                                      when 'xor' then 6
                                      when 'cmp' then 7
                                    end) << 3) + (dst_reg_code & 7))
           || printf('%02x', immediate_value & 255)
         ) as fixed_hex
  from reg_imm
  where op_name in ('add','sub','cmp','and','or','xor')
    and immediate_value between -128 and 127
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_reg_symbol_imm8' as parametric_rule_name,
         (
           case
             when width_bits = 64 then printf('%02x', 72 + case when dst_reg_code >= 8 then 1 else 0 end)
             when dst_requires_rex = 1 then printf('%02x', 64 + case when dst_reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || 'c1'
           || printf('%02x', 192 + ((case op_name
                                      when 'ror' then 1
                                      when 'shl' then 4
                                      when 'shr' then 5
                                      when 'sar' then 7
                                    end) << 3) + (dst_reg_code & 7))
           || printf('%02x', immediate_value & 255)
         ) as fixed_hex
  from reg_imm
  where op_name in ('shl','shr','sar','ror')
    and immediate_value between 0 and 255
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_reg_symbol_base_memory' as parametric_rule_name,
         (
           case
             when op_name = 'movsxd' then printf('%02x', 72 + case when reg_code >= 8 then 4 else 0 end + case when base_reg_code >= 8 then 1 else 0 end)
             when width_bits = 64 then printf('%02x', 72 + case when reg_code >= 8 then 4 else 0 end + case when base_reg_code >= 8 then 1 else 0 end)
             when requires_rex = 1 or base_requires_rex = 1 then printf('%02x', 64 + case when reg_code >= 8 then 4 else 0 end + case when base_reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || case
                when op_name = 'movzx' and size_name = 'byte' then '0fb6'
                when op_name = 'movzx' and size_name = 'word' then '0fb7'
                when op_name = 'movsx' and size_name = 'word' then '0fbf'
                when op_name = 'movsxd' then '63'
                when op_name = 'mov' then '8b'
                when op_name = 'add' then '03'
                when op_name = 'sub' then '2b'
                when op_name = 'cmp' then '3b'
                when op_name = 'and' then '23'
                when op_name = 'or' then '0b'
                when op_name = 'xor' then '33'
                when op_name = 'lea' then '8d'
              end
           || printf('%02x', (mod_bits << 6) + ((reg_code & 7) << 3) + rm_field)
           || sib_hex
           || displacement_hex
         ) as fixed_hex
  from base_symbol_to_reg
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_symbol_base_memory_reg' as parametric_rule_name,
         (
           case
             when width_bits = 64 then printf('%02x', 72 + case when reg_code >= 8 then 4 else 0 end + case when base_reg_code >= 8 then 1 else 0 end)
             when requires_rex = 1 or base_requires_rex = 1 then printf('%02x', 64 + case when reg_code >= 8 then 4 else 0 end + case when base_reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || case
                when op_name = 'mov' and width_bits = 8 then '88'
                when op_name = 'mov' then '89'
                when op_name = 'add' then '01'
                when op_name = 'sub' then '29'
                when op_name = 'cmp' then '39'
                when op_name = 'and' then '21'
                when op_name = 'or' then '09'
                when op_name = 'xor' then '31'
              end
           || printf('%02x', (mod_bits << 6) + ((reg_code & 7) << 3) + rm_field)
           || sib_hex
           || displacement_hex
         ) as fixed_hex
  from reg_to_base_symbol
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_' || size_name || '_symbol_base_memory_imm8' as parametric_rule_name,
         (
           case
             when size_name = 'qword' then printf('%02x', 72 + case when base_reg_code >= 8 then 1 else 0 end)
             when base_requires_rex = 1 then printf('%02x', 64 + case when base_reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || case
                when size_name = 'byte' then '80'
                else '83'
              end
           || printf('%02x', (mod_bits << 6) + ((case op_name
                                                  when 'add' then 0
                                                  when 'sub' then 5
                                                  when 'cmp' then 7
                                                end) << 3) + rm_field)
           || sib_hex
           || displacement_hex
           || printf('%02x', rhs_immediate_value & 255)
         ) as fixed_hex
  from base_symbol_imm
  where op_name in ('add','sub','cmp')
    and rhs_immediate_value between -128 and 127
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_mov_' || size_name || '_symbol_base_memory_imm' as parametric_rule_name,
         (
           case
             when size_name = 'qword' then printf('%02x', 72 + case when base_reg_code >= 8 then 1 else 0 end)
             when base_requires_rex = 1 then printf('%02x', 64 + case when base_reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || case
                when size_name = 'byte' then 'c6'
                else 'c7'
              end
           || printf('%02x', (mod_bits << 6) + rm_field)
           || sib_hex
           || displacement_hex
           || case
                when size_name = 'byte' then printf('%02x', rhs_immediate_value & 255)
                else printf('%02x%02x%02x%02x',
                            rhs_immediate_value & 255,
                            (rhs_immediate_value >> 8) & 255,
                            (rhs_immediate_value >> 16) & 255,
                            (rhs_immediate_value >> 24) & 255)
              end
         ) as fixed_hex
  from base_symbol_imm
  where op_name = 'mov'
    and ((size_name = 'byte' and rhs_immediate_value between -128 and 255)
         or (size_name in ('dword','qword') and rhs_immediate_value between -2147483648 and 4294967295))
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_dword_stack_symbol_imm8' as parametric_rule_name,
         (
           case op_name
             when 'cmp' then '83' || printf('%02x', (mod_bits << 6) + (7 << 3) + 4) || '24' || displacement_hex || printf('%02x', immediate_value & 255)
             when 'add' then '83' || printf('%02x', (mod_bits << 6) + (0 << 3) + 4) || '24' || displacement_hex || printf('%02x', immediate_value & 255)
             when 'sub' then '83' || printf('%02x', (mod_bits << 6) + (5 << 3) + 4) || '24' || displacement_hex || printf('%02x', immediate_value & 255)
           end
         ) as fixed_hex
  from stack_imm
  where size_name = 'dword'
    and op_name in ('add','sub','cmp')
    and immediate_value between -128 and 127
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_mov_dword_stack_symbol_imm32' as parametric_rule_name,
         (
           'c7' || printf('%02x', (mod_bits << 6) + 4) || '24' || displacement_hex
           || printf('%02x%02x%02x%02x',
                     immediate_value & 255,
                     (immediate_value >> 8) & 255,
                     (immediate_value >> 16) & 255,
                     (immediate_value >> 24) & 255)
         ) as fixed_hex
  from stack_imm
  where size_name = 'dword'
    and op_name = 'mov'
    and immediate_value between 0 and 4294967295
)
select repo_file_id,
       function_name,
       line_no,
       parametric_rule_name,
       fixed_hex
from generated
where fixed_hex is not null;

create unique index repo_asm_symbolic_parametric_encoding_fact_line_idx
  on repo_asm_symbolic_parametric_encoding_fact(repo_file_id, function_name, line_no);

create table repo_asm_indexed_parametric_encoding_fact as
with clean_indexed_memory as (
  select *
  from repo_asm_memory_addressing_fact
  where target_isa_id = 1
    and is_rel_memory = 0
    and addressing_kind = 'indexed_memory'
    and symbol_term_count = 0
    and (register_term_count = 2 or (register_term_count = 1 and scaled_register_term_count = 1))
), register_pair_memory as (
  select memory.*,
         first_term.term_text as first_register_name,
         second_term.term_text as second_register_name,
         1 as scale_value
  from clean_indexed_memory memory
  join repo_asm_memory_operand_term_fact first_term
    on first_term.repo_file_id = memory.repo_file_id
   and first_term.function_name = memory.function_name
   and first_term.line_no = memory.line_no
   and first_term.operand_index = memory.operand_index
   and first_term.term_kind = 'register'
   and first_term.term_sign = 1
  join repo_asm_memory_operand_term_fact second_term
    on second_term.repo_file_id = memory.repo_file_id
   and second_term.function_name = memory.function_name
   and second_term.line_no = memory.line_no
   and second_term.operand_index = memory.operand_index
   and second_term.term_kind = 'register'
   and second_term.term_sign = 1
   and second_term.term_index > first_term.term_index
  where memory.register_term_count = 2
    and memory.scaled_register_term_count = 0
), scaled_index_memory as (
  select memory.*,
         base_term.term_text as first_register_name,
         scaled_term.scale_register_name as second_register_name,
         scaled_term.scale_value
  from clean_indexed_memory memory
  join repo_asm_memory_operand_term_fact base_term
    on base_term.repo_file_id = memory.repo_file_id
   and base_term.function_name = memory.function_name
   and base_term.line_no = memory.line_no
   and base_term.operand_index = memory.operand_index
   and base_term.term_kind = 'register'
   and base_term.term_sign = 1
  join repo_asm_memory_operand_term_fact scaled_term
    on scaled_term.repo_file_id = memory.repo_file_id
   and scaled_term.function_name = memory.function_name
   and scaled_term.line_no = memory.line_no
   and scaled_term.operand_index = memory.operand_index
   and scaled_term.term_kind = 'scaled_register'
   and scaled_term.term_sign = 1
  where memory.register_term_count = 1
    and memory.scaled_register_term_count = 1
    and scaled_term.scale_value in (1,2,4,8)
), selected_index_memory as (
  select *
  from register_pair_memory
  union all
  select *
  from scaled_index_memory
), indexed_memory_bytes as (
  select selected_index_memory.*,
         case
           when (second_reg.reg_code & 7) = 4 then second_reg.register_name
           else first_reg.register_name
         end as base_register_name,
         case
           when (second_reg.reg_code & 7) = 4 then first_reg.register_name
           else second_reg.register_name
         end as index_register_name,
         case
           when (second_reg.reg_code & 7) = 4 then second_reg.reg_code
           else first_reg.reg_code
         end as base_reg_code,
         case
           when (second_reg.reg_code & 7) = 4 then second_reg.requires_rex
           else first_reg.requires_rex
         end as base_requires_rex,
         case
           when (second_reg.reg_code & 7) = 4 then first_reg.reg_code
           else second_reg.reg_code
         end as index_reg_code,
         case
           when (second_reg.reg_code & 7) = 4 then first_reg.requires_rex
           else second_reg.requires_rex
         end as index_requires_rex,
         case scale_value when 1 then 0 when 2 then 1 when 4 then 2 when 8 then 3 end as scale_bits,
         case
           when integer_displacement = 0
            and ((case when (second_reg.reg_code & 7) = 4 then second_reg.reg_code else first_reg.reg_code end) & 7) not in (5) then 0
           when integer_displacement between -128 and 127 then 1
           else 2
         end as mod_bits,
         case
           when integer_displacement = 0
            and ((case when (second_reg.reg_code & 7) = 4 then second_reg.reg_code else first_reg.reg_code end) & 7) not in (5) then ''
           when integer_displacement between -128 and 127 then printf('%02x', integer_displacement & 255)
           else printf('%02x%02x%02x%02x',
                       integer_displacement & 255,
                       (integer_displacement >> 8) & 255,
                       (integer_displacement >> 16) & 255,
                       (integer_displacement >> 24) & 255)
         end as displacement_hex,
         printf('%02x',
                ((case scale_value when 1 then 0 when 2 then 1 when 4 then 2 when 8 then 3 end) << 6)
                + (((case when (second_reg.reg_code & 7) = 4 then first_reg.reg_code else second_reg.reg_code end) & 7) << 3)
                + ((case when (second_reg.reg_code & 7) = 4 then second_reg.reg_code else first_reg.reg_code end) & 7)) as sib_hex
  from selected_index_memory
  join x86_register_encoding_fact first_reg
    on first_reg.register_name = selected_index_memory.first_register_name
   and first_reg.width_bits = 64
  join x86_register_encoding_fact second_reg
    on second_reg.register_name = selected_index_memory.second_register_name
   and second_reg.width_bits = 64
  where ((case when (second_reg.reg_code & 7) = 4 then first_reg.reg_code else second_reg.reg_code end) & 7) <> 4
), binary_operand as (
  select match.repo_file_id,
         match.function_name,
         match.line_no,
         match.op_name,
         trim(substr(match.operand_text, 1, instr(match.operand_text, ',') - 1)) as lhs,
         trim(substr(match.operand_text, instr(match.operand_text, ',') + 1)) as rhs
  from repo_asm_rule_match match
  where match.target_isa_id = 1
    and match.line_kind = 3
    and match.encoding_id is null
    and match.rule_name is not null
    and instr(coalesce(match.operand_text, ''), ',') > 0
), normalized as (
  select *,
         case when lhs like 'byte %' then 'byte'
              when lhs like 'word %' then 'word'
              when lhs like 'dword %' then 'dword'
              when lhs like 'qword %' then 'qword'
              else null end as lhs_size,
         case when lhs like 'byte %' then trim(substr(lhs, 6))
              when lhs like 'word %' then trim(substr(lhs, 6))
              when lhs like 'dword %' then trim(substr(lhs, 7))
              when lhs like 'qword %' then trim(substr(lhs, 7))
              else lhs end as lhs_value,
         case when rhs like 'byte %' then 'byte'
              when rhs like 'word %' then 'word'
              when rhs like 'dword %' then 'dword'
              when rhs like 'qword %' then 'qword'
              else null end as rhs_size,
         case when rhs like 'byte %' then trim(substr(rhs, 6))
              when rhs like 'word %' then trim(substr(rhs, 6))
              when rhs like 'dword %' then trim(substr(rhs, 7))
              when rhs like 'qword %' then trim(substr(rhs, 7))
              else rhs end as rhs_value
  from binary_operand
), reg_to_index as (
  select normalized.*,
         reg.register_name,
         reg.width_bits,
         reg.reg_code,
         reg.requires_rex,
         mem.size_name,
         mem.base_reg_code,
         mem.base_requires_rex,
         mem.index_reg_code,
         mem.index_requires_rex,
         mem.mod_bits,
         mem.sib_hex,
         mem.displacement_hex
  from normalized
  join x86_register_encoding_fact reg on reg.register_name = normalized.rhs_value
  join indexed_memory_bytes mem
    on mem.repo_file_id = normalized.repo_file_id
   and mem.function_name = normalized.function_name
   and mem.line_no = normalized.line_no
   and mem.operand_index = 0
  where normalized.op_name in ('mov','add','sub','cmp','and','or','xor')
    and reg.width_bits in (8,32,64)
    and (mem.size_name is null
         or (mem.size_name = 'byte' and reg.width_bits = 8)
         or (mem.size_name = 'dword' and reg.width_bits = 32)
         or (mem.size_name = 'qword' and reg.width_bits = 64))
), index_to_reg as (
  select normalized.*,
         reg.register_name,
         reg.width_bits,
         reg.reg_code,
         reg.requires_rex,
         mem.size_name,
         mem.base_reg_code,
         mem.base_requires_rex,
         mem.index_reg_code,
         mem.index_requires_rex,
         mem.mod_bits,
         mem.sib_hex,
         mem.displacement_hex
  from normalized
  join x86_register_encoding_fact reg on reg.register_name = normalized.lhs_value
  join indexed_memory_bytes mem
    on mem.repo_file_id = normalized.repo_file_id
   and mem.function_name = normalized.function_name
   and mem.line_no = normalized.line_no
   and mem.operand_index = 1
  where normalized.op_name in ('mov','add','sub','cmp','and','or','xor','lea','movzx','movsx','movsxd')
    and reg.width_bits in (32,64)
    and (mem.size_name is null
         or (mem.size_name = 'byte' and normalized.op_name = 'movzx')
         or (mem.size_name = 'word' and normalized.op_name in ('movzx','movsx'))
         or (mem.size_name = 'dword' and reg.width_bits in (32,64))
         or (mem.size_name = 'qword' and reg.width_bits = 64))
), generated as (
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_reg_index_memory' as parametric_rule_name,
         (
           case
             when op_name = 'movsxd' then printf('%02x', 72 + case when reg_code >= 8 then 4 else 0 end + case when index_reg_code >= 8 then 2 else 0 end + case when base_reg_code >= 8 then 1 else 0 end)
             when width_bits = 64 then printf('%02x', 72 + case when reg_code >= 8 then 4 else 0 end + case when index_reg_code >= 8 then 2 else 0 end + case when base_reg_code >= 8 then 1 else 0 end)
             when requires_rex = 1 or base_requires_rex = 1 or index_requires_rex = 1 then printf('%02x', 64 + case when reg_code >= 8 then 4 else 0 end + case when index_reg_code >= 8 then 2 else 0 end + case when base_reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || case
                when op_name = 'movzx' and size_name = 'byte' then '0fb6'
                when op_name = 'movzx' and size_name = 'word' then '0fb7'
                when op_name = 'movsx' and size_name = 'word' then '0fbf'
                when op_name = 'movsxd' then '63'
                when op_name = 'mov' then '8b'
                when op_name = 'add' then '03'
                when op_name = 'sub' then '2b'
                when op_name = 'cmp' then '3b'
                when op_name = 'and' then '23'
                when op_name = 'or' then '0b'
                when op_name = 'xor' then '33'
                when op_name = 'lea' then '8d'
              end
           || printf('%02x', (mod_bits << 6) + ((reg_code & 7) << 3) + 4)
           || sib_hex
           || displacement_hex
         ) as fixed_hex
  from index_to_reg
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_index_memory_reg' as parametric_rule_name,
         (
           case
             when width_bits = 64 then printf('%02x', 72 + case when reg_code >= 8 then 4 else 0 end + case when index_reg_code >= 8 then 2 else 0 end + case when base_reg_code >= 8 then 1 else 0 end)
             when requires_rex = 1 or base_requires_rex = 1 or index_requires_rex = 1 then printf('%02x', 64 + case when reg_code >= 8 then 4 else 0 end + case when index_reg_code >= 8 then 2 else 0 end + case when base_reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || case
                when op_name = 'mov' and width_bits = 8 then '88'
                when op_name = 'mov' then '89'
                when op_name = 'add' then '01'
                when op_name = 'sub' then '29'
                when op_name = 'cmp' then '39'
                when op_name = 'and' then '21'
                when op_name = 'or' then '09'
                when op_name = 'xor' then '31'
              end
           || printf('%02x', (mod_bits << 6) + ((reg_code & 7) << 3) + 4)
           || sib_hex
           || displacement_hex
         ) as fixed_hex
  from reg_to_index
)
select repo_file_id,
       function_name,
       line_no,
       parametric_rule_name,
       fixed_hex
from generated
where fixed_hex is not null;

create unique index repo_asm_indexed_parametric_encoding_fact_line_idx
  on repo_asm_indexed_parametric_encoding_fact(repo_file_id, function_name, line_no);

create table repo_asm_numeric_symbol_memory_parametric_encoding_fact as
with symbolic_memory as (
  select mem.*,
         base_term.term_text as base_register_name,
         symbol_term.term_text as symbol_name,
         (mem.integer_displacement + (symbol_term.term_sign * value.immediate_value)) as displacement
  from repo_asm_memory_addressing_fact mem
  join repo_asm_memory_operand_term_fact base_term
    on base_term.repo_file_id = mem.repo_file_id
   and base_term.function_name = mem.function_name
   and base_term.line_no = mem.line_no
   and base_term.operand_index = mem.operand_index
   and base_term.term_kind = 'register'
   and base_term.term_sign = 1
  join repo_asm_memory_operand_term_fact symbol_term
    on symbol_term.repo_file_id = mem.repo_file_id
   and symbol_term.function_name = mem.function_name
   and symbol_term.line_no = mem.line_no
   and symbol_term.operand_index = mem.operand_index
   and symbol_term.term_kind = 'symbol'
  join repo_asm_numeric_constant_value value
    on value.symbol_name = symbol_term.term_text
  where mem.target_isa_id = 1
    and mem.is_rel_memory = 0
    and mem.addressing_kind = 'symbolic_base_memory'
    and mem.register_term_count = 1
    and mem.symbol_term_count = 1
    and mem.scaled_register_term_count = 0
), symbolic_memory_bytes as (
  select symbolic_memory.*,
         base_reg.reg_code as base_reg_code,
         base_reg.requires_rex as base_requires_rex,
         case
           when displacement = 0 and (base_reg.reg_code & 7) not in (5) then 0
           when displacement between -128 and 127 then 1
           else 2
         end as mod_bits,
         case
           when displacement = 0 and (base_reg.reg_code & 7) not in (5) then ''
           when displacement between -128 and 127 then printf('%02x', displacement & 255)
           else printf('%02x%02x%02x%02x',
                       displacement & 255,
                       (displacement >> 8) & 255,
                       (displacement >> 16) & 255,
                       (displacement >> 24) & 255)
         end as displacement_hex,
         case when (base_reg.reg_code & 7) = 4 then '24' else '' end as sib_hex,
         case when (base_reg.reg_code & 7) = 4 then 4 else (base_reg.reg_code & 7) end as rm_field
  from symbolic_memory
  join x86_register_encoding_fact base_reg
    on base_reg.register_name = symbolic_memory.base_register_name
   and base_reg.width_bits = 64
), reg_to_symbol_memory as (
  select mem.*,
         reg.operand_value as register_name,
         reg_encoding.width_bits,
         reg_encoding.reg_code,
         reg_encoding.requires_rex
  from symbolic_memory_bytes mem
  join repo_asm_binary_operand_fact reg
    on reg.repo_file_id = mem.repo_file_id
   and reg.function_name = mem.function_name
   and reg.line_no = mem.line_no
   and reg.operand_index = 1
   and reg.operand_kind = 'register'
  join x86_register_encoding_fact reg_encoding
    on reg_encoding.register_name = reg.operand_value
  where mem.operand_index = 0
    and mem.op_name in ('mov','add','sub','cmp','and','or','xor')
    and reg_encoding.width_bits in (8,32,64)
    and (mem.size_name is null
         or (mem.size_name = 'byte' and reg_encoding.width_bits = 8)
         or (mem.size_name = 'dword' and reg_encoding.width_bits = 32)
         or (mem.size_name = 'qword' and reg_encoding.width_bits = 64))
), symbol_memory_to_reg as (
  select mem.*,
         reg.operand_value as register_name,
         reg_encoding.width_bits,
         reg_encoding.reg_code,
         reg_encoding.requires_rex
  from symbolic_memory_bytes mem
  join repo_asm_binary_operand_fact reg
    on reg.repo_file_id = mem.repo_file_id
   and reg.function_name = mem.function_name
   and reg.line_no = mem.line_no
   and reg.operand_index = 0
   and reg.operand_kind = 'register'
  join x86_register_encoding_fact reg_encoding
    on reg_encoding.register_name = reg.operand_value
  where mem.operand_index = 1
    and mem.op_name in ('mov','add','sub','cmp','and','or','xor','lea','movzx','movsx','movsxd')
    and reg_encoding.width_bits in (32,64)
    and (mem.size_name is null
         or (mem.size_name = 'byte' and mem.op_name = 'movzx')
         or (mem.size_name = 'word' and mem.op_name in ('movzx','movsx'))
         or (mem.size_name = 'dword' and reg_encoding.width_bits in (32,64))
         or (mem.size_name = 'qword' and reg_encoding.width_bits = 64))
), rhs_integer as (
  select operand.repo_file_id,
         operand.function_name,
         operand.line_no,
         cast(operand.operand_value as integer) as immediate_value
  from repo_asm_binary_operand_fact operand
  where operand.operand_index = 1
    and (operand.operand_value glob '[0-9]*'
         or operand.operand_value glob '-[0-9]*')
    and replace(operand.operand_value, '-', '') not glob '*[^0-9]*'
  union all
  select operand.repo_file_id,
         operand.function_name,
         operand.line_no,
         value.immediate_value
  from repo_asm_binary_operand_fact operand
  join repo_asm_numeric_constant_value value
    on value.symbol_name = operand.operand_value
  where operand.operand_index = 1
), symbol_memory_imm as (
  select mem.*,
         rhs_integer.immediate_value as rhs_immediate_value
  from symbolic_memory_bytes mem
  join rhs_integer
    on rhs_integer.repo_file_id = mem.repo_file_id
   and rhs_integer.function_name = mem.function_name
   and rhs_integer.line_no = mem.line_no
  where mem.operand_index = 0
    and mem.op_name in ('mov','add','sub','cmp')
    and mem.size_name in ('byte','dword','qword')
), generated as (
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_reg_numeric_symbol_memory' as parametric_rule_name,
         (
           case
             when op_name = 'movsxd' then printf('%02x', 72 + case when reg_code >= 8 then 4 else 0 end + case when base_reg_code >= 8 then 1 else 0 end)
             when width_bits = 64 then printf('%02x', 72 + case when reg_code >= 8 then 4 else 0 end + case when base_reg_code >= 8 then 1 else 0 end)
             when requires_rex = 1 or base_requires_rex = 1 then printf('%02x', 64 + case when reg_code >= 8 then 4 else 0 end + case when base_reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || case
                when op_name = 'movzx' and size_name = 'byte' then '0fb6'
                when op_name = 'movzx' and size_name = 'word' then '0fb7'
                when op_name = 'movsx' and size_name = 'word' then '0fbf'
                when op_name = 'movsxd' then '63'
                when op_name = 'mov' then '8b'
                when op_name = 'add' then '03'
                when op_name = 'sub' then '2b'
                when op_name = 'cmp' then '3b'
                when op_name = 'and' then '23'
                when op_name = 'or' then '0b'
                when op_name = 'xor' then '33'
                when op_name = 'lea' then '8d'
              end
           || printf('%02x', (mod_bits << 6) + ((reg_code & 7) << 3) + rm_field)
           || sib_hex
           || displacement_hex
         ) as fixed_hex
  from symbol_memory_to_reg
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_' || size_name || '_numeric_symbol_memory_imm8' as parametric_rule_name,
         (
           case
             when size_name = 'qword' then printf('%02x', 72 + case when base_reg_code >= 8 then 1 else 0 end)
             when base_requires_rex = 1 then printf('%02x', 64 + case when base_reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || case
                when size_name = 'byte' then '80'
                else '83'
              end
           || printf('%02x', (mod_bits << 6) + ((case op_name
                                                  when 'add' then 0
                                                  when 'sub' then 5
                                                  when 'cmp' then 7
                                                end) << 3) + rm_field)
           || sib_hex
           || displacement_hex
           || printf('%02x', rhs_immediate_value & 255)
         ) as fixed_hex
  from symbol_memory_imm
  where op_name in ('add','sub','cmp')
    and rhs_immediate_value between -128 and 127
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_mov_' || size_name || '_numeric_symbol_memory_imm' as parametric_rule_name,
         (
           case
             when size_name = 'qword' then printf('%02x', 72 + case when base_reg_code >= 8 then 1 else 0 end)
             when base_requires_rex = 1 then printf('%02x', 64 + case when base_reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || case
                when size_name = 'byte' then 'c6'
                else 'c7'
              end
           || printf('%02x', (mod_bits << 6) + rm_field)
           || sib_hex
           || displacement_hex
           || case
                when size_name = 'byte' then printf('%02x', rhs_immediate_value & 255)
                else printf('%02x%02x%02x%02x',
                            rhs_immediate_value & 255,
                            (rhs_immediate_value >> 8) & 255,
                            (rhs_immediate_value >> 16) & 255,
                            (rhs_immediate_value >> 24) & 255)
              end
         ) as fixed_hex
  from symbol_memory_imm
  where op_name = 'mov'
    and ((size_name = 'byte' and rhs_immediate_value between -128 and 255)
         or (size_name in ('dword','qword') and rhs_immediate_value between -2147483648 and 4294967295))
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_numeric_symbol_memory_reg' as parametric_rule_name,
         (
           case
             when width_bits = 64 then printf('%02x', 72 + case when reg_code >= 8 then 4 else 0 end + case when base_reg_code >= 8 then 1 else 0 end)
             when requires_rex = 1 or base_requires_rex = 1 then printf('%02x', 64 + case when reg_code >= 8 then 4 else 0 end + case when base_reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || case
                when op_name = 'mov' and width_bits = 8 then '88'
                when op_name = 'mov' then '89'
                when op_name = 'add' then '01'
                when op_name = 'sub' then '29'
                when op_name = 'cmp' then '39'
                when op_name = 'and' then '21'
                when op_name = 'or' then '09'
                when op_name = 'xor' then '31'
              end
           || printf('%02x', (mod_bits << 6) + ((reg_code & 7) << 3) + rm_field)
           || sib_hex
           || displacement_hex
         ) as fixed_hex
  from reg_to_symbol_memory
)
select repo_file_id,
       function_name,
       line_no,
       parametric_rule_name,
       fixed_hex
from generated
where fixed_hex is not null
  and not exists (select 1
                  from repo_asm_parametric_encoding_fact previous
                  where previous.repo_file_id = generated.repo_file_id
                    and previous.function_name = generated.function_name
                    and previous.line_no = generated.line_no)
  and not exists (select 1
                  from repo_asm_symbolic_parametric_encoding_fact previous
                  where previous.repo_file_id = generated.repo_file_id
                    and previous.function_name = generated.function_name
                    and previous.line_no = generated.line_no)
  and not exists (select 1
                  from repo_asm_indexed_parametric_encoding_fact previous
                  where previous.repo_file_id = generated.repo_file_id
                    and previous.function_name = generated.function_name
                    and previous.line_no = generated.line_no);

create unique index repo_asm_numeric_symbol_memory_parametric_encoding_fact_line_idx
  on repo_asm_numeric_symbol_memory_parametric_encoding_fact(repo_file_id, function_name, line_no);

create table repo_asm_numeric_immediate_parametric_encoding_fact as
with recursive rhs_decimal as (
  select operand.repo_file_id,
         operand.function_name,
         operand.line_no,
         cast(operand.operand_value as integer) as immediate_value
  from repo_asm_binary_operand_fact operand
  where operand.target_isa_id = 1
    and operand.operand_index = 1
    and (operand.operand_value glob '[0-9]*'
         or operand.operand_value glob '-[0-9]*')
    and replace(operand.operand_value, '-', '') not glob '*[^0-9]*'
), rhs_hex_seed as (
  select operand.repo_file_id,
         operand.function_name,
         operand.line_no,
         substr(lower(operand.operand_value), 3) as hex_text
  from repo_asm_binary_operand_fact operand
  where operand.target_isa_id = 1
    and operand.operand_index = 1
    and lower(operand.operand_value) glob '0x[0-9a-f]*'
    and substr(lower(operand.operand_value), 3) <> ''
    and substr(lower(operand.operand_value), 3) not glob '*[^0-9a-f]*'
    and length(substr(lower(operand.operand_value), 3)) <= 15
), rhs_hex_parse(repo_file_id, function_name, line_no, hex_text, digit_index, immediate_value) as (
  select repo_file_id,
         function_name,
         line_no,
         hex_text,
         1 as digit_index,
         0 as immediate_value
  from rhs_hex_seed
  union all
  select repo_file_id,
         function_name,
         line_no,
         hex_text,
         digit_index + 1,
         (immediate_value * 16) + instr('0123456789abcdef', substr(hex_text, digit_index, 1)) - 1
  from rhs_hex_parse
  where digit_index <= length(hex_text)
), rhs_hex as (
  select repo_file_id,
         function_name,
         line_no,
         immediate_value
  from rhs_hex_parse
  where digit_index = length(hex_text) + 1
), rhs_symbol as (
  select operand.repo_file_id,
         operand.function_name,
         operand.line_no,
         value.immediate_value
  from repo_asm_binary_operand_fact operand
  join repo_asm_numeric_constant_value value
    on value.symbol_name = operand.operand_value
  where operand.target_isa_id = 1
    and operand.operand_index = 1
), rhs_value as (
  select * from rhs_decimal
  union all
  select * from rhs_hex
  union all
  select * from rhs_symbol
), rhs_unique_value as (
  select repo_file_id,
         function_name,
         line_no,
         min(immediate_value) as immediate_value
  from rhs_value
  group by repo_file_id, function_name, line_no
  having min(immediate_value) = max(immediate_value)
), reg_imm as (
  select match.repo_file_id,
         match.function_name,
         match.line_no,
         match.op_name,
         reg.operand_value as register_name,
         reg_encoding.width_bits,
         reg_encoding.reg_code,
         reg_encoding.requires_rex,
         rhs_unique_value.immediate_value
  from repo_asm_rule_match match
  join repo_asm_binary_operand_fact reg
    on reg.repo_file_id = match.repo_file_id
   and reg.function_name = match.function_name
   and reg.line_no = match.line_no
   and reg.operand_index = 0
   and reg.operand_kind = 'register'
  join x86_register_encoding_fact reg_encoding
    on reg_encoding.register_name = reg.operand_value
  join rhs_unique_value
    on rhs_unique_value.repo_file_id = match.repo_file_id
   and rhs_unique_value.function_name = match.function_name
   and rhs_unique_value.line_no = match.line_no
  where match.target_isa_id = 1
    and match.line_kind = 3
    and match.encoding_id is null
    and match.rule_name is not null
    and match.op_name in ('mov','add','sub','cmp','and','or','xor','test','shl','shr','sar','ror')
    and reg_encoding.width_bits in (8,32,64)
), generated as (
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_mov_reg8_numeric_imm8' as parametric_rule_name,
         (
           case
             when requires_rex = 1 then printf('%02x', 64 + case when reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || printf('%02x', 176 + (reg_code & 7))
           || printf('%02x', immediate_value & 255)
         ) as fixed_hex
  from reg_imm
  where op_name = 'mov'
    and width_bits = 8
    and immediate_value between -128 and 255
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_mov_reg_numeric_imm32' as parametric_rule_name,
         (
           case
             when requires_rex = 1 then printf('%02x', 64 + case when reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || printf('%02x', 184 + (reg_code & 7))
           || printf('%02x%02x%02x%02x',
                     immediate_value & 255,
                     (immediate_value >> 8) & 255,
                     (immediate_value >> 16) & 255,
                     (immediate_value >> 24) & 255)
         ) as fixed_hex
  from reg_imm
  where op_name = 'mov'
    and width_bits = 32
    and immediate_value between -2147483648 and 4294967295
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_mov_reg64_numeric_imm32' as parametric_rule_name,
         (
           printf('%02x', 72 + case when reg_code >= 8 then 1 else 0 end)
           || 'c7'
           || printf('%02x', 192 + (reg_code & 7))
           || printf('%02x%02x%02x%02x',
                     immediate_value & 255,
                     (immediate_value >> 8) & 255,
                     (immediate_value >> 16) & 255,
                     (immediate_value >> 24) & 255)
         ) as fixed_hex
  from reg_imm
  where op_name = 'mov'
    and width_bits = 64
    and immediate_value between -2147483648 and 2147483647
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_mov_reg64_numeric_imm64' as parametric_rule_name,
         (
           printf('%02x', 72 + case when reg_code >= 8 then 1 else 0 end)
           || printf('%02x', 184 + (reg_code & 7))
           || printf('%02x%02x%02x%02x%02x%02x%02x%02x',
                     immediate_value & 255,
                     (immediate_value >> 8) & 255,
                     (immediate_value >> 16) & 255,
                     (immediate_value >> 24) & 255,
                     (immediate_value >> 32) & 255,
                     (immediate_value >> 40) & 255,
                     (immediate_value >> 48) & 255,
                     (immediate_value >> 56) & 255)
         ) as fixed_hex
  from reg_imm
  where op_name = 'mov'
    and width_bits = 64
    and immediate_value > 2147483647
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_reg_numeric_imm8' as parametric_rule_name,
         (
           case
             when width_bits = 64 then printf('%02x', 72 + case when reg_code >= 8 then 1 else 0 end)
             when requires_rex = 1 then printf('%02x', 64 + case when reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || '83'
           || printf('%02x', 192 + ((case op_name
                                      when 'add' then 0
                                      when 'or' then 1
                                      when 'and' then 4
                                      when 'sub' then 5
                                      when 'xor' then 6
                                      when 'cmp' then 7
                                    end) << 3) + (reg_code & 7))
           || printf('%02x', immediate_value & 255)
         ) as fixed_hex
  from reg_imm
  where op_name in ('add','sub','cmp','and','or','xor')
    and immediate_value between -128 and 127
    and width_bits in (32,64)
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_reg8_numeric_imm8' as parametric_rule_name,
         (
           case
             when requires_rex = 1 then printf('%02x', 64 + case when reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || case
                when op_name = 'test' and reg_code = 0 then 'a8'
                when op_name = 'test' then 'f6' || printf('%02x', 192 + (reg_code & 7))
                when reg_code = 0 then case op_name
                                        when 'add' then '04'
                                        when 'or' then '0c'
                                        when 'and' then '24'
                                        when 'sub' then '2c'
                                        when 'xor' then '34'
                                        when 'cmp' then '3c'
                                      end
                else '80' || printf('%02x', 192 + ((case op_name
                                                     when 'add' then 0
                                                     when 'or' then 1
                                                     when 'and' then 4
                                                     when 'sub' then 5
                                                     when 'xor' then 6
                                                     when 'cmp' then 7
                                                   end) << 3) + (reg_code & 7))
              end
           || printf('%02x', immediate_value & 255)
         ) as fixed_hex
  from reg_imm
  where op_name in ('add','sub','cmp','and','or','xor','test')
    and width_bits = 8
    and immediate_value between -128 and 255
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_reg_numeric_imm8' as parametric_rule_name,
         (
           case
             when width_bits = 64 then printf('%02x', 72 + case when reg_code >= 8 then 1 else 0 end)
             when requires_rex = 1 then printf('%02x', 64 + case when reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || 'c1'
           || printf('%02x', 192 + ((case op_name
                                      when 'ror' then 1
                                      when 'shl' then 4
                                      when 'shr' then 5
                                      when 'sar' then 7
                                    end) << 3) + (reg_code & 7))
           || printf('%02x', immediate_value & 255)
         ) as fixed_hex
  from reg_imm
  where op_name in ('shl','shr','sar','ror')
    and immediate_value between 0 and 255
)
select repo_file_id,
       function_name,
       line_no,
       parametric_rule_name,
       fixed_hex
from generated
where fixed_hex is not null
  and not exists (select 1
                  from repo_asm_parametric_encoding_fact previous
                  where previous.repo_file_id = generated.repo_file_id
                    and previous.function_name = generated.function_name
                    and previous.line_no = generated.line_no)
  and not exists (select 1
                  from repo_asm_symbolic_parametric_encoding_fact previous
                  where previous.repo_file_id = generated.repo_file_id
                    and previous.function_name = generated.function_name
                    and previous.line_no = generated.line_no)
  and not exists (select 1
                  from repo_asm_indexed_parametric_encoding_fact previous
                  where previous.repo_file_id = generated.repo_file_id
                    and previous.function_name = generated.function_name
                    and previous.line_no = generated.line_no)
  and not exists (select 1
                  from repo_asm_numeric_symbol_memory_parametric_encoding_fact previous
                  where previous.repo_file_id = generated.repo_file_id
                    and previous.function_name = generated.function_name
                    and previous.line_no = generated.line_no);

create unique index repo_asm_numeric_immediate_parametric_encoding_fact_line_idx
  on repo_asm_numeric_immediate_parametric_encoding_fact(repo_file_id, function_name, line_no);

create table repo_asm_unary_parametric_encoding_fact as
with register_operand as (
  select match.repo_file_id,
         match.function_name,
         match.line_no,
         match.op_name,
         match.operand_text as register_name,
         reg.width_bits,
         reg.reg_code,
         reg.requires_rex
  from repo_asm_rule_match match
  join x86_register_encoding_fact reg
    on reg.register_name = match.operand_text
  where match.target_isa_id = 1
    and match.line_kind = 3
    and match.encoding_id is null
    and match.rule_name is not null
    and match.op_name in ('inc','dec','neg','not')
), unary_memory_operand as (
  select match.repo_file_id,
         match.function_name,
         match.line_no,
         match.target_isa_id,
         match.op_name,
         match.operand_text,
         case when match.operand_text like 'byte %' then 'byte'
              when match.operand_text like 'word %' then 'word'
              when match.operand_text like 'dword %' then 'dword'
              when match.operand_text like 'qword %' then 'qword'
              else null end as size_name,
         case when match.operand_text like 'byte %' then trim(substr(match.operand_text, 6))
              when match.operand_text like 'word %' then trim(substr(match.operand_text, 6))
              when match.operand_text like 'dword %' then trim(substr(match.operand_text, 7))
              when match.operand_text like 'qword %' then trim(substr(match.operand_text, 7))
              else match.operand_text end as memory_text
  from repo_asm_rule_match match
  where match.target_isa_id = 1
    and match.line_kind = 3
    and match.encoding_id is null
    and match.rule_name is not null
    and match.op_name in ('inc','dec','neg','not')
), unary_memory_terms as (
  select unary_memory_operand.*,
         trim(replace(substr(memory_text, 2, length(memory_text) - 2), ' - ', ' + -')) as inner_text
  from unary_memory_operand
  where memory_text like '[%]'
), simple_memory as (
  select unary_memory_terms.*,
         case
           when inner_text like '% + %' then trim(substr(inner_text, 1, instr(inner_text, ' + ') - 1))
           else inner_text
         end as base_register_name,
         case
           when inner_text not like '% + %' then 0
           when trim(substr(inner_text, instr(inner_text, ' + ') + 3)) glob '[0-9]*'
            and trim(substr(inner_text, instr(inner_text, ' + ') + 3)) not glob '*[^0-9]*'
             then cast(trim(substr(inner_text, instr(inner_text, ' + ') + 3)) as integer)
           when trim(substr(inner_text, instr(inner_text, ' + ') + 3)) glob '-[0-9]*'
            and replace(trim(substr(inner_text, instr(inner_text, ' + ') + 3)), '-', '') not glob '*[^0-9]*'
             then cast(trim(substr(inner_text, instr(inner_text, ' + ') + 3)) as integer)
         end as displacement
  from unary_memory_terms
  where inner_text not like '% + % + %'
    and inner_text not like '%*%'
    and inner_text not glob '*[ABCDEFGHIJKLMNOPQRSTUVWXYZ_]*'
), numeric_symbol_memory as (
  select unary_memory_terms.*,
         trim(substr(inner_text, 1, instr(inner_text, ' + ') - 1)) as base_register_name,
         value.immediate_value as displacement
  from unary_memory_terms
  join repo_asm_numeric_constant_value value
    on value.symbol_name = trim(substr(inner_text, instr(inner_text, ' + ') + 3))
  where inner_text like '% + %'
    and inner_text not like '% + % + %'
    and inner_text not like '%*%'
), memory_operand as (
  select *
  from simple_memory
  union all
  select *
  from numeric_symbol_memory
), memory_bytes as (
  select memory_operand.*,
         base_reg.reg_code as base_reg_code,
         base_reg.requires_rex as base_requires_rex,
         case
           when displacement = 0 and (base_reg.reg_code & 7) not in (5) then 0
           when displacement between -128 and 127 then 1
           else 2
         end as mod_bits,
         case
           when displacement = 0 and (base_reg.reg_code & 7) not in (5) then ''
           when displacement between -128 and 127 then printf('%02x', displacement & 255)
           else printf('%02x%02x%02x%02x',
                       displacement & 255,
                       (displacement >> 8) & 255,
                       (displacement >> 16) & 255,
                       (displacement >> 24) & 255)
         end as displacement_hex,
         case when (base_reg.reg_code & 7) = 4 then '24' else '' end as sib_hex,
         case when (base_reg.reg_code & 7) = 4 then 4 else (base_reg.reg_code & 7) end as rm_field
  from memory_operand
  join x86_register_encoding_fact base_reg
    on base_reg.register_name = memory_operand.base_register_name
   and base_reg.width_bits = 64
), generated as (
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_reg' as parametric_rule_name,
         (
           case
             when width_bits = 64 then printf('%02x', 72 + case when reg_code >= 8 then 1 else 0 end)
             when requires_rex = 1 then printf('%02x', 64 + case when reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || case
                when op_name in ('inc','dec') and width_bits = 8 then 'fe'
                when op_name in ('inc','dec') then 'ff'
                when width_bits = 8 then 'f6'
                else 'f7'
              end
           || printf('%02x', 192 + ((case op_name
                                      when 'inc' then 0
                                      when 'dec' then 1
                                      when 'not' then 2
                                      when 'neg' then 3
                                    end) << 3) + (reg_code & 7))
         ) as fixed_hex
  from register_operand
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_' || size_name || '_memory' as parametric_rule_name,
         (
           case
             when size_name = 'qword' then printf('%02x', 72 + case when base_reg_code >= 8 then 1 else 0 end)
             when base_requires_rex = 1 then printf('%02x', 64 + case when base_reg_code >= 8 then 1 else 0 end)
             else ''
           end
           || case
                when op_name in ('inc','dec') and size_name = 'byte' then 'fe'
                when op_name in ('inc','dec') then 'ff'
                when size_name = 'byte' then 'f6'
                else 'f7'
              end
           || printf('%02x', (mod_bits << 6) + ((case op_name
                                                  when 'inc' then 0
                                                  when 'dec' then 1
                                                  when 'not' then 2
                                                  when 'neg' then 3
                                                end) << 3) + rm_field)
           || sib_hex
           || displacement_hex
         ) as fixed_hex
  from memory_bytes
  where op_name in ('inc','dec','neg','not')
    and size_name in ('byte','word','dword','qword')
)
select repo_file_id,
       function_name,
       line_no,
       parametric_rule_name,
       fixed_hex
from generated
where fixed_hex is not null
  and not exists (select 1
                  from repo_asm_parametric_encoding_fact previous
                  where previous.repo_file_id = generated.repo_file_id
                    and previous.function_name = generated.function_name
                    and previous.line_no = generated.line_no)
  and not exists (select 1
                  from repo_asm_symbolic_parametric_encoding_fact previous
                  where previous.repo_file_id = generated.repo_file_id
                    and previous.function_name = generated.function_name
                    and previous.line_no = generated.line_no)
  and not exists (select 1
                  from repo_asm_indexed_parametric_encoding_fact previous
                  where previous.repo_file_id = generated.repo_file_id
                    and previous.function_name = generated.function_name
                    and previous.line_no = generated.line_no)
  and not exists (select 1
                  from repo_asm_numeric_symbol_memory_parametric_encoding_fact previous
                  where previous.repo_file_id = generated.repo_file_id
                    and previous.function_name = generated.function_name
                    and previous.line_no = generated.line_no)
  and not exists (select 1
                  from repo_asm_numeric_immediate_parametric_encoding_fact previous
                  where previous.repo_file_id = generated.repo_file_id
                    and previous.function_name = generated.function_name
                    and previous.line_no = generated.line_no);

create unique index repo_asm_unary_parametric_encoding_fact_line_idx
  on repo_asm_unary_parametric_encoding_fact(repo_file_id, function_name, line_no);

create table repo_asm_stack_alias_parametric_encoding_fact as
with binary_operand as (
  select match.repo_file_id,
         match.function_name,
         match.line_no,
         match.op_name,
         match.operand_text,
         trim(substr(match.operand_text, 1, instr(match.operand_text, ',') - 1)) as lhs,
         trim(substr(match.operand_text, instr(match.operand_text, ',') + 1)) as rhs,
         constant_expr.symbol_name,
         trim(constant_expr.expression_text) as expression_text
  from repo_asm_rule_match match
  join repo_asm_constant_expression_fact constant_expr
    on constant_expr.repo_file_id = match.repo_file_id
   and constant_expr.function_name = match.function_name
   and constant_expr.line_no = match.line_no
  where match.target_isa_id = 1
    and match.line_kind = 3
    and match.encoding_id is null
    and match.rule_name is not null
    and constant_expr.symbol_count = 1
    and instr(coalesce(match.operand_text, ''), ',') > 0
), normalized as (
  select *,
         case when lhs like 'byte %' then 'byte'
              when lhs like 'word %' then 'word'
              when lhs like 'dword %' then 'dword'
              when lhs like 'qword %' then 'qword'
              else null end as lhs_size,
         case when lhs like 'byte %' then trim(substr(lhs, 6))
              when lhs like 'word %' then trim(substr(lhs, 6))
              when lhs like 'dword %' then trim(substr(lhs, 7))
              when lhs like 'qword %' then trim(substr(lhs, 7))
              else lhs end as lhs_value,
         case when rhs like 'byte %' then 'byte'
              when rhs like 'word %' then 'word'
              when rhs like 'dword %' then 'dword'
              when rhs like 'qword %' then 'qword'
              else null end as rhs_size,
         case when rhs like 'byte %' then trim(substr(rhs, 6))
              when rhs like 'word %' then trim(substr(rhs, 6))
              when rhs like 'dword %' then trim(substr(rhs, 7))
              when rhs like 'qword %' then trim(substr(rhs, 7))
              else rhs end as rhs_value
  from binary_operand
), alias_value as (
  select *,
         case
           when replace(expression_text, ' ', '') glob 'rsp+[0-9]*'
            and substr(replace(expression_text, ' ', ''), 5) not glob '*[^0-9]*'
             then cast(substr(replace(expression_text, ' ', ''), 5) as integer)
           when replace(expression_text, ' ', '') glob 'rsp-[0-9]*'
            and substr(replace(expression_text, ' ', ''), 5) not glob '*[^0-9]*'
             then -cast(substr(replace(expression_text, ' ', ''), 5) as integer)
           when replace(expression_text, ' ', '') = 'rsp' then 0
         end as displacement
  from normalized
), memory_operand as (
  select repo_file_id,
         function_name,
         line_no,
         op_name,
         lhs_value,
         rhs_value,
         lhs_size as size_name,
         rhs_value as register_name,
         displacement,
         symbol_name,
         'lhs' as memory_side
  from alias_value
  where lhs_value like '[%]'
    and substr(lhs_value, 2, length(lhs_value) - 2) = symbol_name
  union all
  select repo_file_id,
         function_name,
         line_no,
         op_name,
         lhs_value,
         rhs_value,
         rhs_size as size_name,
         lhs_value as register_name,
         displacement,
         symbol_name,
         'rhs' as memory_side
  from alias_value
  where rhs_value like '[%]'
    and substr(rhs_value, 2, length(rhs_value) - 2) = symbol_name
), memory_bytes as (
  select memory_operand.*,
         reg.width_bits,
         reg.reg_code,
         reg.requires_rex,
         case
           when displacement = 0 then 0
           when displacement between -128 and 127 then 1
           else 2
         end as mod_bits,
         case
           when displacement = 0 then ''
           when displacement between -128 and 127 then printf('%02x', displacement & 255)
           else printf('%02x%02x%02x%02x',
                       displacement & 255,
                       (displacement >> 8) & 255,
                       (displacement >> 16) & 255,
                       (displacement >> 24) & 255)
         end as displacement_hex
  from memory_operand
  join x86_register_encoding_fact reg
    on reg.register_name = memory_operand.register_name
  where displacement is not null
    and reg.width_bits in (32,64)
), generated as (
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_stack_alias_reg' as parametric_rule_name,
         (
           case
             when width_bits = 64 then printf('%02x', 72 + case when reg_code >= 8 then 4 else 0 end)
             when requires_rex = 1 then printf('%02x', 64 + case when reg_code >= 8 then 4 else 0 end)
             else ''
           end
           || case
                when op_name = 'mov' then '89'
                when op_name = 'add' then '01'
                when op_name = 'sub' then '29'
                when op_name = 'cmp' then '39'
                when op_name = 'and' then '21'
                when op_name = 'or' then '09'
                when op_name = 'xor' then '31'
              end
           || printf('%02x', (mod_bits << 6) + ((reg_code & 7) << 3) + 4)
           || '24'
           || displacement_hex
         ) as fixed_hex
  from memory_bytes
  where memory_side = 'lhs'
    and op_name in ('mov','add','sub','cmp','and','or','xor')
  union all
  select repo_file_id,
         function_name,
         line_no,
         'param_x86_' || op_name || '_reg_stack_alias' as parametric_rule_name,
         (
           case
             when width_bits = 64 then printf('%02x', 72 + case when reg_code >= 8 then 4 else 0 end)
             when requires_rex = 1 then printf('%02x', 64 + case when reg_code >= 8 then 4 else 0 end)
             else ''
           end
           || case op_name
                when 'mov' then '8b'
                when 'add' then '03'
                when 'sub' then '2b'
                when 'cmp' then '3b'
                when 'and' then '23'
                when 'or' then '0b'
                when 'xor' then '33'
                when 'lea' then '8d'
              end
           || printf('%02x', (mod_bits << 6) + ((reg_code & 7) << 3) + 4)
           || '24'
           || displacement_hex
         ) as fixed_hex
  from memory_bytes
  where memory_side = 'rhs'
    and op_name in ('mov','add','sub','cmp','and','or','xor','lea')
)
select repo_file_id,
       function_name,
       line_no,
       parametric_rule_name,
       fixed_hex
from generated
where fixed_hex is not null
  and not exists (select 1
                  from repo_asm_parametric_encoding_fact previous
                  where previous.repo_file_id = generated.repo_file_id
                    and previous.function_name = generated.function_name
                    and previous.line_no = generated.line_no)
  and not exists (select 1
                  from repo_asm_symbolic_parametric_encoding_fact previous
                  where previous.repo_file_id = generated.repo_file_id
                    and previous.function_name = generated.function_name
                    and previous.line_no = generated.line_no)
  and not exists (select 1
                  from repo_asm_indexed_parametric_encoding_fact previous
                  where previous.repo_file_id = generated.repo_file_id
                    and previous.function_name = generated.function_name
                    and previous.line_no = generated.line_no)
  and not exists (select 1
                  from repo_asm_numeric_symbol_memory_parametric_encoding_fact previous
                  where previous.repo_file_id = generated.repo_file_id
                    and previous.function_name = generated.function_name
                    and previous.line_no = generated.line_no)
  and not exists (select 1
                  from repo_asm_numeric_immediate_parametric_encoding_fact previous
                  where previous.repo_file_id = generated.repo_file_id
                    and previous.function_name = generated.function_name
                    and previous.line_no = generated.line_no)
  and not exists (select 1
                  from repo_asm_unary_parametric_encoding_fact previous
                  where previous.repo_file_id = generated.repo_file_id
                    and previous.function_name = generated.function_name
                    and previous.line_no = generated.line_no);

create unique index repo_asm_stack_alias_parametric_encoding_fact_line_idx
  on repo_asm_stack_alias_parametric_encoding_fact(repo_file_id, function_name, line_no);

create table repo_asm_all_parametric_encoding_fact as
select *
from repo_asm_parametric_encoding_fact
union all
select *
from repo_asm_symbolic_parametric_encoding_fact
union all
select *
from repo_asm_indexed_parametric_encoding_fact
union all
select *
from repo_asm_numeric_symbol_memory_parametric_encoding_fact
union all
select *
from repo_asm_numeric_immediate_parametric_encoding_fact
union all
select *
from repo_asm_unary_parametric_encoding_fact
union all
select *
from repo_asm_stack_alias_parametric_encoding_fact;

create unique index repo_asm_all_parametric_encoding_fact_line_idx
  on repo_asm_all_parametric_encoding_fact(repo_file_id, function_name, line_no);

create view repo_asm_all_parametric_encoding_conflict as
select match.path,
       match.function_name,
       match.line_no,
       match.op_name,
       match.operand_text,
       match.fixed_hex as exact_hex,
       parametric.fixed_hex as parametric_hex,
       parametric.parametric_rule_name
from repo_asm_rule_match match
join repo_asm_all_parametric_encoding_fact parametric
  on parametric.repo_file_id = match.repo_file_id
 and parametric.function_name = match.function_name
 and parametric.line_no = match.line_no
where match.fixed_hex is not null
  and lower(match.fixed_hex) <> lower(parametric.fixed_hex);

create view repo_asm_materializable_operation as
select *
from repo_asm_rule_match
where encoding_id is not null;

create view repo_asm_file_materialization_progress as
select path,
       count(*) as operation_count,
       sum(case when encoding_id is not null then 1 else 0 end) as materializable_count,
       count(*) - sum(case when encoding_id is not null then 1 else 0 end) as remaining_count,
       (100 * sum(case when encoding_id is not null then 1 else 0 end)) / count(*) as materializable_percent
from repo_asm_rule_match
where line_kind = 3
group by path
order by materializable_percent desc, remaining_count asc, path;

create view repo_asm_next_encoding_candidates as
select fact_status.op_name,
       fact_status.operand_text,
       count(*) as occurrence_count,
       count(distinct fact_status.path) as file_count,
       count(distinct fact_status.function_name) as function_count
from repo_asm_operation_fact_status fact_status
where fact_status.fact_status = 'known_gap'
group by fact_status.op_name, fact_status.operand_text
order by occurrence_count desc, op_name, operand_text;

create view repo_asm_label_decl_fact as
select path,
       repo_file_id,
       function_name,
       line_no,
       substr(trim(raw_text), 1, length(trim(raw_text)) - 1) as label_name,
       case when substr(trim(raw_text), 1, 1) = '.' then 'local' else 'global' end as label_scope
from repo_asm_operation
where line_kind = 2;

create view repo_asm_control_target_fact as
select path,
       repo_file_id,
       function_name,
       line_no,
       op_name,
       operand_text as target_name,
       case
         when op_name = 'call' or op_name = 'er_call' then 'call'
         when op_name = 'bl' then 'call'
         when op_name in ('jmp','je','jne','jz','jnz','ja','jae','jb','jbe','jg','jge','jl','jle','jc','jnc','jo','jno','js','jns') then 'branch'
         when op_name in ('b','beq','bne','blo','bhi','bhs','bls') then 'branch'
         else 'unknown'
       end as target_kind
from repo_asm_operation
where line_kind = 3
  and operand_text is not null
  and op_name in ('call','er_call','jmp','je','jne','jz','jnz','ja','jae','jb','jbe','jg','jge','jl','jle','jc','jnc','jo','jno','js','jns',
                  'bl','b','beq','bne','blo','bhi','bhs','bls');

create view repo_asm_control_edge_fact as
select target.path,
       target.function_name,
       target.line_no as from_line_no,
       label.line_no as to_line_no,
       target.op_name,
       target.target_name,
       target.target_kind
from repo_asm_control_target_fact target
join repo_asm_label_decl_fact label
  on label.repo_file_id = target.repo_file_id
 and label.function_name = target.function_name
 and label.label_name = target.target_name;

create view repo_asm_unresolved_control_target as
select target.*
from repo_asm_control_target_fact target
left join repo_asm_control_edge_fact edge
  on edge.path = target.path
 and edge.function_name = target.function_name
 and edge.from_line_no = target.line_no
where edge.from_line_no is null;

create view repo_asm_external_control_target_fact as
select *
from repo_asm_unresolved_control_target
where target_name not like '.%';

create view repo_asm_unresolved_local_control_target as
select *
from repo_asm_unresolved_control_target
where target_name like '.%';

create table asm_macro_lowering_rule (
  macro_name text primary key,
  lowered_operation_pattern text not null,
  result_kind text not null
);

insert into asm_macro_lowering_rule(macro_name, lowered_operation_pattern, result_kind) values
  ('er_ok', 'xor edx, edx', 'fixed_instruction'),
  ('er_err', 'mov edx, $arg0', 'fixed_instruction_with_immediate'),
  ('er_ret', 'ret', 'fixed_instruction'),
  ('er_check_zero', 'test $arg0, $arg0; jz $arg1', 'control_sequence'),
  ('er_check_nonzero', 'test $arg0, $arg0; jnz $arg1', 'control_sequence'),
  ('er_push', 'push each argument left-to-right', 'stack_sequence'),
  ('er_pop', 'pop each argument right-to-left', 'stack_sequence'),
  ('er_pop_ret', 'pop each argument right-to-left; ret', 'stack_sequence'),
  ('er_stack_alloc', 'sub rsp, $arg0', 'stack_adjust'),
  ('er_stack_free', 'add rsp, $arg0', 'stack_adjust'),
  ('er_call', 'call $arg0; test edx, edx; jnz $arg1', 'control_sequence'),
  ('er_frame_push', 'push rbp; mov rbp, rsp', 'stack_sequence'),
  ('er_frame_pop', 'pop rbp', 'stack_sequence'),
  ('er_frame_push_regs', 'push frame then listed registers', 'stack_sequence'),
  ('TEST', 'compare eax and edx; branch to failure on mismatch', 'test_assertion'),
  ('ASSERT_EQ', 'compare actual and expected values; fail test on mismatch', 'test_assertion'),
  ('ASSERT_RAX', 'compare rax against expected value; fail test on mismatch', 'test_assertion'),
  ('ASSERT_RDX', 'compare rdx against expected value; fail test on mismatch', 'test_assertion'),
  ('TESTQ', 'compare rax and rdx; branch to failure on mismatch', 'test_assertion'),
  ('TEST_MEM', 'compare memory ranges; branch to failure on mismatch', 'test_assertion'),
  ('TEST_BSS_PASSED_FAILED', 'check BSS zeroing and branch to pass/fail result', 'test_assertion'),
  ('TEST_BSS_TOTAL_PASSED', 'check accumulated BSS/test totals and branch to pass result', 'test_assertion'),
  ('TEST_DATA_PASSED_FAILED', 'define pass/fail test data and labels', 'test_data'),
  ('TEST_DATA_TOTAL_PASSED_FAILED', 'define pass/fail/total test data and labels', 'test_data'),
  ('ASSERT_TRUE', 'assert nonzero value; fail test on mismatch', 'test_assertion'),
  ('TEST_ARM_EXIT_FAIL', 'exit ARM test with failure status', 'test_exit'),
  ('TEST_ARM_EXIT_OK', 'exit ARM test with success status', 'test_exit'),
  ('TEST_FAIL', 'branch to test failure result', 'test_exit'),
  ('TEST_PASS', 'branch to test pass result', 'test_exit'),
  ('TEST_CASE_PASS', 'record one test case pass', 'test_assertion'),
  ('PRINT_STR', 'emit test status string', 'test_output'),
  ('EXPECT_EAX', 'compare eax against expected value and branch on mismatch', 'test_assertion'),
  ('CRB_SEND_CHECK', 'TPM CRB send/check helper macro', 'test_assertion'),
  ('call_read_bit', 'read one AV1 bool bit into local state', 'macro_sequence'),
  ('write_bits', 'write constant AV1 bit pattern', 'macro_sequence'),
  ('write_one_from_esi', 'write one AV1 bit from esi', 'macro_sequence'),
  ('wasm_exec_reader_ptr', 'load WASM execution reader pointer', 'macro_sequence'),
  ('wasm_exec_save_reader_offset', 'persist WASM execution reader offset', 'macro_sequence'),
  ('wasm_decode_finish_op', 'finish current WASM decode operation', 'macro_sequence'),
  ('slip_encode', 'encode ESP32 serial payload with SLIP framing', 'macro_sequence'),
  ('slip_decode', 'decode ESP32 serial SLIP payload', 'macro_sequence'),
  ('mp4_load_be32', 'load big-endian MP4 dword into register', 'macro_sequence'),
  ('jit_template_pop_rcx_rax', 'JIT template bytes for pop rcx and pop rax', 'jit_template'),
  ('jit_template_push_rax_ret', 'JIT template bytes for push rax and ret', 'jit_template'),
  ('jit_template_setcc_push_ret', 'JIT template bytes for setcc, push, ret', 'jit_template'),
  ('jit_template_setcc_and_push', 'JIT template bytes for setcc and push', 'jit_template'),
  ('jit_template_modrm_c0_push_rax', 'JIT template bytes with modrm c0 and push rax', 'jit_template'),
  ('er_ret_true', 'return true from helper macro', 'macro_sequence'),
  ('read_bits', 'read constant-width AV1 field', 'macro_sequence'),
  ('TEST_SKIP', 'mark current test case skipped', 'test_assertion'),
  ('_blake3_round', 'expand BLAKE3 round macro', 'macro_sequence'),
  ('er_expect_token_operand_result', 'expect parsed token operand result', 'test_assertion'),
  ('er_push_expect_token_operand_result', 'push and expect parsed token operand result', 'test_assertion'),
  ('er_expect_line_end_result', 'expect parser line-end result', 'test_assertion'),
  ('er_emit_text_bytes', 'emit expected text bytes for parser tests', 'test_data'),
  ('zero_loop_filter_delta_state', 'clear AV1 loop-filter delta state', 'macro_sequence'),
  ('zero_global_motion_state', 'clear AV1 global motion state', 'macro_sequence'),
  ('jit_template_modrm82_disp_r11', 'JIT template bytes with modrm82 displacement via r11', 'jit_template'),
  ('jit_template_emit_mov_accum_rdx', 'JIT template bytes for mov accumulator rdx', 'jit_template'),
  ('jit_template_jmp_rel32_placeholder', 'JIT template placeholder for rel32 jmp', 'jit_template'),
  ('jit_template_jns_rel32_placeholder', 'JIT template placeholder for rel32 jns', 'jit_template'),
  ('jit_template_patch_rel32', 'JIT template rel32 patch helper', 'jit_template'),
  ('jit_template_push_rax', 'JIT template push rax bytes', 'jit_template'),
  ('jit_template_setcc_push', 'JIT template setcc push bytes', 'jit_template'),
  ('ser_putchar_sil_imm', 'write immediate byte through serial helper', 'macro_sequence'),
  ('FE_CARRY_PASS', 'run field element carry propagation pass', 'macro_sequence'),
  ('_cmos_in_data', 'read CMOS data port into al', 'macro_sequence'),
  ('_ec_in_status', 'read embedded-controller status port into al', 'macro_sequence'),
  ('_i8042_in_status', 'read i8042 status port into al', 'macro_sequence'),
  ('mp4_load_be16', 'load big-endian MP4 word into register', 'macro_sequence'),
  ('write_esi_bits', 'write AV1 bit field from esi', 'macro_sequence'),
  ('zero_delta_state', 'clear AV1 delta state', 'macro_sequence'),
  ('zero_film_grain_state', 'clear AV1 film-grain state', 'macro_sequence'),
  ('zero_motion_tool_state', 'clear AV1 motion-tool state', 'macro_sequence'),
  ('zero_segmentation_state', 'clear AV1 segmentation state', 'macro_sequence'),
  ('_init_op', 'initialize WASM execution opcode dispatch metadata', 'macro_sequence'),
  ('_jit_init_op', 'initialize WASM JIT opcode dispatch metadata', 'macro_sequence'),
  ('TEST_ARM_CALL', 'call ARM-side self-test case', 'test_assertion'),
  ('jc_lcd_cmd_data_checked', 'send checked JC LCD command/data sequence', 'macro_sequence'),
  ('er_store_struct_qword', 'store checked qword field in structure array', 'macro_sequence'),
  ('er_store_struct_byte', 'store checked byte field in structure array', 'macro_sequence'),
  ('write_byte_field_bits', 'write AV1 byte field with explicit bit count', 'macro_sequence'),
  ('ADDMUL', 'expand Curve25519 add/multiply limb step', 'macro_sequence'),
  ('GLOBAL', 'declare exported Curve25519 symbol', 'metadata_macro'),
  ('_wasm_cmpop', 'define WASM comparison opcode constant', 'macro_sequence'),
  ('at', 'BLAKE3 vector lane selector macro', 'macro_sequence'),
  ('check_byte_max_rcx', 'check AV1 byte field max in rcx', 'macro_sequence'),
  ('av1_call_check', 'call AV1 helper and branch on error', 'macro_sequence'),
  ('write_bit_field', 'write AV1 one-bit field', 'macro_sequence'),
  ('TEST_DEBUG_LABEL', 'emit test debug label metadata', 'test_data'),
  ('write_byte_field_max_bits', 'write AV1 byte field constrained by max bits', 'macro_sequence'),
  ('_wasm_binop', 'define WASM binary opcode constant', 'macro_sequence'),
  ('_wasm_shiftop', 'define WASM shift opcode constant', 'macro_sequence'),
  ('ser_puts', 'write string through serial helper', 'macro_sequence'),
  ('test_status', 'define HTTP macro test status case', 'test_data'),
  ('TEST_ARM_EXPECT_EQ_CODE', 'assert ARM test code equals expected value', 'test_assertion'),
  ('TEST_ARM_EXPECT_ZERO_CODE', 'assert ARM test code is zero', 'test_assertion'),
  ('_blake3_g_pair', 'expand paired BLAKE3 G rounds', 'macro_sequence'),
  ('read_segment_feature', 'read AV1 segmentation feature field', 'macro_sequence'),
  ('write_segment_feature', 'write AV1 segmentation feature field', 'macro_sequence'),
  ('er_load_struct_qword', 'load checked qword field from structure array', 'macro_sequence'),
  ('av1_read_symbol_check', 'read AV1 symbol and branch on error', 'macro_sequence'),
  ('MUL_CONST_LIMB', 'multiply Curve25519 limb by constant', 'macro_sequence'),
  ('REDUCE_COEFF', 'reduce Curve25519 coefficient into limb range', 'macro_sequence'),
  ('SELECT_LIMB', 'select Curve25519 limb by index', 'macro_sequence'),
  ('check_byte_zero_rcx', 'check AV1 byte field is zero in rcx', 'macro_sequence'),
  ('check_dword_signed_rcx', 'check signed AV1 dword range in rcx', 'macro_sequence'),
  ('read_delta_q_to', 'read AV1 delta-q field into destination', 'macro_sequence'),
  ('write_delta_q_from', 'write AV1 delta-q field from source', 'macro_sequence'),
  ('_cmos_out_index', 'write CMOS index port from source register', 'macro_sequence'),
  ('av1_decode_residual_8x8', 'decode AV1 residual 8x8 block', 'macro_sequence'),
  ('av1_reconstruct_current_8x8', 'reconstruct current AV1 8x8 block', 'macro_sequence'),
  ('av1_route_first_payload', 'route first AV1 payload buffer', 'macro_sequence'),
  ('er_render_ir_push_impl', 'push render IR command implementation', 'macro_sequence'),
  ('jc_lcd_chunk_burst_checked', 'send checked JC LCD chunk burst', 'macro_sequence'),
  ('jit_template_f32_round', 'JIT template for f32 rounding helper', 'jit_template'),
  ('jit_template_f32_sse_bin_tail', 'JIT template for f32 SSE binary tail', 'jit_template'),
  ('jit_template_f64_round', 'JIT template for f64 rounding helper', 'jit_template'),
  ('jit_template_f64_sse_bin_tail', 'JIT template for f64 SSE binary tail', 'jit_template'),
  ('test_cl', 'define CL register parser test', 'test_data'),
  ('test_is_sse', 'define SSE parser test expectation', 'test_data'),
  ('test_sse_ptr', 'define SSE pointer parser test', 'test_data'),
  ('TEST_EXIT', 'exit with explicit test status', 'test_exit'),
  ('TEST_EXIT_FAILED', 'exit with failed test status', 'test_exit'),
  ('TEST_EXIT_PASSED_TOTAL', 'exit with accumulated test result', 'test_exit');

create view repo_asm_macro_lowering_fact as
select repo_asm_operation.path,
       repo_asm_operation.repo_file_id,
       repo_asm_operation.function_name,
       repo_asm_operation.line_no,
       repo_asm_operation.op_name as macro_name,
       repo_asm_operation.operand_text,
       asm_macro_lowering_rule.lowered_operation_pattern,
       asm_macro_lowering_rule.result_kind
from repo_asm_operation
join asm_macro_lowering_rule on asm_macro_lowering_rule.macro_name = repo_asm_operation.op_name;

create view repo_asm_macro_lowering_gap as
select repo_asm_rule_gaps.path,
       repo_asm_rule_gaps.function_name,
       repo_asm_rule_gaps.line_no,
       repo_asm_rule_gaps.op_name,
       repo_asm_rule_gaps.operand_text,
       repo_asm_rule_gaps.raw_text
from repo_asm_rule_gaps
left join asm_macro_lowering_rule on asm_macro_lowering_rule.macro_name = repo_asm_rule_gaps.op_name
where repo_asm_rule_gaps.gap_kind = 'macro_without_lowering'
  and asm_macro_lowering_rule.macro_name is null;

create view repo_asm_relocation_fact as
select path,
       repo_file_id,
       function_name,
       line_no,
       op_name,
       target_name,
       target_kind,
       case
         when target_kind = 'call' then 'rel32_call'
         when target_kind = 'branch' and target_name like '.%' then 'local_branch'
         when target_kind = 'branch' then 'rel32_branch_or_tailcall'
         else 'unknown'
       end as relocation_kind
from repo_asm_control_target_fact;

create table asm_zero_size_data_symbol_fact (
  path text not null,
  label_name text not null,
  symbol_kind text not null,
  primary key (path, label_name)
);

insert into asm_zero_size_data_symbol_fact(path, label_name, symbol_kind) values
  ('kernel/host/er_obj_body.asm.erobj', 'stack_top', 'reserved_stack_end_anchor'),
  ('kernel/test/test_av1_ivf_self.asm', 'ivf_av1', 'labelled_data_block_anchor'),
  ('kernel/test/test_av1_mp4_self.asm', 'mp4_headers', 'labelled_data_block_anchor'),
  ('kernel/test/test_av1_mp4_self.asm', 'mp4_tables', 'labelled_data_block_anchor'),
  ('kernel/test/test_av1_mp4_self.asm', 'mp4_time_tables', 'labelled_data_block_anchor'),
  ('kernel/test/test_curve25519_self.asm', 't1', 'labelled_data_block_anchor'),
  ('kernel/test/test_curve25519_self.asm', 't3', 'labelled_data_block_anchor');

create table repo_asm_label_data_anchor_fact as
with operation_window as (
  select path,
         repo_file_id,
         function_name,
         line_no,
         op_name,
         operand_text,
         lag(op_name) over (partition by repo_file_id order by line_no) as previous_op_name,
         lag(operand_text) over (partition by repo_file_id order by line_no) as previous_operand_text,
         lead(op_name) over (partition by repo_file_id order by line_no) as next_op_name
  from repo_asm_operation
  where line_kind in (2,3,5)
)
select path,
       repo_file_id,
       function_name,
       line_no,
       op_name as label_name,
       'labelled_data_block_anchor' as data_definition_kind
from operation_window
where op_name like '%:'
  and operand_text is null
  and (next_op_name in ('db','dw','dd','dq','incbin','times','.byte','.asciz','.space','resb','resw','resd','resq')
       or previous_op_name in ('db','dw','dd','dq','incbin','times','.byte','.asciz','.space','resb','resw','resd','resq')
       or previous_operand_text like 'db %'
       or previous_operand_text like 'dw %'
       or previous_operand_text like 'dd %'
       or previous_operand_text like 'dq %'
       or previous_operand_text like 'incbin %'
       or previous_operand_text like 'times %'
       or previous_operand_text like '.byte %'
       or previous_operand_text like '.asciz %'
       or previous_operand_text like '.space %'
       or previous_operand_text like 'resb %'
       or previous_operand_text like 'resw %'
       or previous_operand_text like 'resd %'
       or previous_operand_text like 'resq %')
  and not exists (
    select 1
    from asm_zero_size_data_symbol_fact symbol
    where symbol.path = operation_window.path
      and symbol.label_name = replace(operation_window.op_name, ':', '')
  );

create index repo_asm_label_data_anchor_fact_line_idx
  on repo_asm_label_data_anchor_fact(repo_file_id, function_name, line_no);
create index repo_asm_label_data_anchor_fact_label_idx
  on repo_asm_label_data_anchor_fact(repo_file_id, label_name);

create view repo_asm_data_reference_fact as
select path,
       repo_file_id,
       function_name,
       line_no,
       op_name,
       trim(substr(operand_text,
                   instr(operand_text, '[rel ') + 5,
                   instr(substr(operand_text, instr(operand_text, '[rel ') + 5), ']') - 1)) as target_name,
       'rip_rel32_data' as relocation_kind
from repo_asm_operation
where operand_text like '%[rel %]%'
union all
select path,
       repo_file_id,
       function_name,
       line_no,
       op_name,
       trim(substr(operand_text,
                   instr(operand_text, '=') + 1)) as target_name,
       'arm_literal_pool_reference' as relocation_kind
from repo_asm_operation
where target_isa_id = 4
  and op_name = 'ldr'
  and operand_text like '%, =%'
union all
select operation.path,
       operation.repo_file_id,
       operation.function_name,
       operation.line_no,
       operation.op_name,
       replace(definition.label_name, ':', '') as target_name,
       'absolute_symbol_memory_reference' as relocation_kind
from repo_asm_operation operation
join repo_asm_data_definition_fact definition
  on definition.repo_file_id = operation.repo_file_id
 and replace(definition.label_name, ':', '') = trim(substr(operation.operand_text,
                                                         instr(operation.operand_text, '[') + 1,
                                                         instr(substr(operation.operand_text,
                                                                      instr(operation.operand_text, '[') + 1), ']') - 1))
where operation.op_name in ('mov','lea','add')
  and operation.operand_text like '%, [%]%'
  and operation.operand_text not like '%[rel %]%'
union all
select operation.path,
       operation.repo_file_id,
       operation.function_name,
       operation.line_no,
       operation.op_name,
       replace(definition.label_name, ':', '') as target_name,
       'absolute_symbol_memory_reference' as relocation_kind
from repo_asm_operation operation
join repo_asm_memory_addressing_fact memory
  on memory.repo_file_id = operation.repo_file_id
 and memory.function_name = operation.function_name
 and memory.line_no = operation.line_no
join repo_asm_data_definition_fact definition
  on definition.repo_file_id = operation.repo_file_id
 and replace(definition.label_name, ':', '') = memory.first_symbol_term
where operation.op_name in ('mov','lea','add','sub','cmp','and','or','xor','test','movzx')
  and memory.addressing_kind = 'symbolic_base_memory'
  and memory.symbol_term_count = 1
  and memory.rel_marker_count = 0
union all
select operation.path,
       operation.repo_file_id,
       operation.function_name,
       operation.line_no,
       operation.op_name,
       replace(definition.label_name, ':', '') as target_name,
       'symbol_data_reference' as relocation_kind
from repo_asm_operation operation
join repo_asm_data_definition_fact definition
  on definition.repo_file_id = operation.repo_file_id
 and replace(definition.label_name, ':', '') = trim(substr(operation.operand_text, instr(operation.operand_text, ',') + 1))
where operation.op_name in ('mov','lea')
  and operation.operand_text like '%, %'
  and operation.operand_text not like '%[rel %]%'
union all
select operation.path,
       operation.repo_file_id,
       operation.function_name,
       operation.line_no,
       operation.op_name,
       replace(definition.label_name, ':', '') as target_name,
       'symbol_data_reference' as relocation_kind
from repo_asm_operation operation
join repo_asm_data_definition_fact definition
  on definition.repo_file_id = operation.repo_file_id
 and replace(definition.label_name, ':', '') = trim(substr(trim(substr(operation.operand_text, instr(operation.operand_text, ',') + 1)),
                                                        1,
                                                        instr(trim(substr(operation.operand_text, instr(operation.operand_text, ',') + 1)), ' + ') - 1))
where operation.op_name in ('mov','lea','add','sub','cmp')
  and operation.operand_text like '%, % + %'
  and operation.operand_text not like '%[rel %]%';

create table repo_asm_data_definition_fact as
select path,
       repo_file_id,
       function_name,
       line_no,
       op_name as label_name,
       operand_text,
       case
         when operand_text like 'resb %' then 'reserved_bytes'
         when operand_text like 'resw %' then 'reserved_words'
         when operand_text like 'resd %' then 'reserved_dwords'
         when operand_text like 'resq %' then 'reserved_qwords'
         when operand_text like 'dq %' then 'quadword_data'
         when operand_text like 'dd %' then 'dword_data'
         when operand_text like 'dw %' then 'word_data'
         when operand_text like 'db %' then 'byte_data'
         when operand_text like '.asciz %' then 'zero_terminated_string_data'
         when operand_text like '.space %' then 'reserved_bytes'
         when operand_text like 'times % db %' then 'repeated_byte_data'
         else 'unknown_data_definition'
       end as data_definition_kind
from repo_asm_operation
where op_name like '%:'
  and (operand_text like 'resb %'
       or operand_text like 'resw %'
       or operand_text like 'resd %'
       or operand_text like 'resq %'
       or operand_text like 'dq %'
       or operand_text like 'dd %'
       or operand_text like 'dw %'
       or operand_text like 'db %'
       or operand_text like '.asciz %'
       or operand_text like '.space %'
       or operand_text like 'times % db %'
       or operand_text like 'incbin %')
union all
select path,
       repo_file_id,
       function_name,
       line_no,
       '' as label_name,
       operand_text,
       'included_binary_data' as data_definition_kind
from repo_asm_operation
where op_name = 'incbin'
  and operand_text is not null
union all
select operation.path,
       operation.repo_file_id,
       operation.function_name,
       operation.line_no,
       operation.op_name as label_name,
       operation.operand_text,
       symbol.symbol_kind as data_definition_kind
from repo_asm_operation operation
join asm_zero_size_data_symbol_fact symbol
  on symbol.path = operation.path
 and symbol.label_name = replace(operation.op_name, ':', '')
where operation.op_name like '%:'
  and operation.operand_text is null
union all
select path,
       repo_file_id,
       function_name,
       line_no,
       label_name,
       null as operand_text,
       data_definition_kind
from repo_asm_label_data_anchor_fact
union all
select path,
       repo_file_id,
       function_name,
       line_no,
       '' as label_name,
       operand_text,
       case
         when op_name = 'db' then 'byte_data'
         when op_name = 'dw' then 'word_data'
         when op_name = 'dd' then 'dword_data'
         when op_name = 'dq' then 'quadword_data'
         when op_name = '.byte' then 'byte_data'
         when op_name = 'times' and operand_text like '% db %' then 'repeated_byte_data'
         when op_name = '.asciz' then 'zero_terminated_string_data'
         when op_name = '.space' then 'reserved_bytes'
         when op_name = 'resb' then 'reserved_bytes'
         when op_name = 'resw' then 'reserved_words'
         when op_name = 'resd' then 'reserved_dwords'
         when op_name = 'resq' then 'reserved_qwords'
         else 'unknown_data_definition'
       end as data_definition_kind
from repo_asm_operation
where op_name in ('db','dw','dd','dq','.byte','times','.asciz','.space','resb','resw','resd','resq')
  and operand_text is not null;

create index repo_asm_data_definition_fact_line_idx
  on repo_asm_data_definition_fact(repo_file_id, function_name, line_no);
create index repo_asm_data_definition_fact_label_idx
  on repo_asm_data_definition_fact(repo_file_id, label_name);

create table asm_metadata_op_fact (
  op_name text primary key
);

insert into asm_metadata_op_fact(op_name) values
  ('default'), ('SECTION'), ('section'), ('align'), ('.syntax'), ('.cpu'), ('.arm'), ('.align'),
  ('.section'), ('.word'), ('.include'), ('.globl'), ('.equ'), ('.extern'), ('.weak'),
  ('[BITS'), ('struc'), ('@'), ('endstruc'), ('extern');

create view repo_asm_binary_include_dependency_fact as
select path,
       repo_file_id,
       function_name,
       line_no,
       operand_text as binary_include_path,
       'incbin_dependency' as dependency_kind
from repo_asm_operation
where op_name = 'incbin'
  and operand_text is not null
union all
select path,
       repo_file_id,
       function_name,
       line_no,
       substr(operand_text, 8) as binary_include_path,
       'labelled_incbin_dependency' as dependency_kind
from repo_asm_operation
where op_name like '%:'
  and operand_text like 'incbin %';

create table repo_asm_operation_fact_status as
select match.path,
       match.repo_file_id,
       match.function_name,
       match.line_no,
       match.target_isa_id,
       match.line_kind,
       match.op_name,
       match.operand_text,
	       match.raw_text,
	       case
	          when match.encoding_id is not null then 'fixed_encoding'
	          when parametric.fixed_hex is not null then 'fixed_encoding'
	          when relocation.relocation_kind is not null then 'relocation'
	          when data_ref.relocation_kind is not null then 'data_relocation'
	          when macro.macro_name is not null then 'macro_lowered'
          when data_def.data_definition_kind is not null then 'data_definition'
          when constant_expr.symbol_name is not null then 'constant_expression'
          when metadata.op_name is not null then 'metadata'
          when match.line_kind in (1,2,4,5) then 'metadata'
          when match.rule_name is not null then 'known_gap'
         else 'syntax_gap'
	       end as fact_status,
	       match.encoding_id,
	       coalesce(relocation.relocation_kind, data_ref.relocation_kind) as relocation_kind,
	       macro.result_kind as macro_result_kind
	from repo_asm_rule_match match
	left join repo_asm_all_parametric_encoding_fact parametric
	  on parametric.repo_file_id = match.repo_file_id
	 and parametric.function_name = match.function_name
	 and parametric.line_no = match.line_no
	left join repo_asm_relocation_fact relocation
	  on relocation.repo_file_id = match.repo_file_id
  and relocation.function_name = match.function_name
  and relocation.line_no = match.line_no
left join (
  select repo_file_id,
         function_name,
         line_no,
         min(relocation_kind) as relocation_kind
  from repo_asm_data_reference_fact
  group by repo_file_id, function_name, line_no
) data_ref
  on data_ref.repo_file_id = match.repo_file_id
 and data_ref.function_name = match.function_name
 and data_ref.line_no = match.line_no
left join repo_asm_constant_expression_fact constant_expr
  on constant_expr.repo_file_id = match.repo_file_id
 and constant_expr.function_name = match.function_name
 and constant_expr.line_no = match.line_no
left join repo_asm_macro_lowering_fact macro
  on macro.repo_file_id = match.repo_file_id
  and macro.function_name = match.function_name
  and macro.line_no = match.line_no
left join repo_asm_data_definition_fact data_def
  on data_def.repo_file_id = match.repo_file_id
 and data_def.function_name = match.function_name
 and data_def.line_no = match.line_no
left join asm_metadata_op_fact metadata
  on metadata.op_name = match.op_name;

create index repo_asm_operation_fact_status_status_idx on repo_asm_operation_fact_status(fact_status);
create index repo_asm_operation_fact_status_next_idx on repo_asm_operation_fact_status(fact_status, op_name, operand_text);
create index repo_asm_operation_fact_status_file_idx on repo_asm_operation_fact_status(path, fact_status);

create view repo_asm_deletion_readiness as
select path,
       count(*) as operation_count,
       sum(case when fact_status = 'fixed_encoding' then 1 else 0 end) as fixed_encoding_count,
       sum(case when fact_status = 'relocation' then 1 else 0 end) as relocation_count,
       sum(case when fact_status = 'data_relocation' then 1 else 0 end) as data_relocation_count,
       sum(case when fact_status = 'macro_lowered' then 1 else 0 end) as macro_lowered_count,
       sum(case when fact_status = 'data_definition' then 1 else 0 end) as data_definition_count,
       sum(case when fact_status = 'constant_expression' then 1 else 0 end) as constant_expression_count,
       sum(case when fact_status = 'metadata' then 1 else 0 end) as metadata_count,
       sum(case when fact_status in ('fixed_encoding','relocation','data_relocation','macro_lowered','data_definition','constant_expression','metadata') then 1 else 0 end) as fact_backed_count,
       count(*) - sum(case when fact_status in ('fixed_encoding','relocation','data_relocation','macro_lowered','data_definition','constant_expression','metadata') then 1 else 0 end)
         + coalesce((select unparsed_line_count from repo_asm_parse_coverage coverage where coverage.path = repo_asm_operation_fact_status.path), 0) as remaining_count,
       coalesce((select unparsed_line_count from repo_asm_parse_coverage coverage where coverage.path = repo_asm_operation_fact_status.path), 0) as unparsed_line_count,
       coalesce((select parsed_percent from repo_asm_parse_coverage coverage where coverage.path = repo_asm_operation_fact_status.path), 0) as parsed_percent,
       (100 * sum(case when fact_status in ('fixed_encoding','relocation','data_relocation','macro_lowered','data_definition','constant_expression','metadata') then 1 else 0 end)) / count(*) as fact_backed_percent
from repo_asm_operation_fact_status
group by path
order by fact_backed_percent desc, remaining_count asc, path;

create view repo_asm_remaining_gap as
select path,
       repo_file_id,
       function_name,
       line_no,
       op_name,
       operand_text,
       raw_text,
       fact_status as gap_kind
from repo_asm_operation_fact_status
where fact_status in ('known_gap', 'syntax_gap');

create view repo_asm_remaining_meaning_gap as
select path,
       repo_file_id,
       function_name,
       line_no,
       op_name,
       operand_text,
       raw_text,
       gap_kind
from repo_asm_remaining_gap
union all
select path,
       repo_file_id,
       '' as function_name,
       line_no,
       '' as op_name,
       '' as operand_text,
       text as raw_text,
       gap_kind
from repo_asm_unparsed_significant_line;

create view repo_asm_remaining_gap_summary as
select gap_kind,
       op_name,
       operand_text,
       count(*) as occurrence_count,
       count(distinct path) as file_count,
       count(distinct function_name) as function_count
from repo_asm_remaining_gap
group by gap_kind, op_name, operand_text
order by occurrence_count desc, gap_kind, op_name, operand_text;

create view repo_asm_remaining_meaning_gap_summary as
select gap_kind,
       op_name,
       operand_text,
       count(*) as occurrence_count,
       count(distinct path) as file_count
from repo_asm_remaining_meaning_gap
group by gap_kind, op_name, operand_text
order by occurrence_count desc, gap_kind, op_name, operand_text;

create table repo_asm_source_deletion_plan as
select repo_file.path,
       repo_file.file_kind,
       repo_file.byte_len,
       readiness.operation_count,
       coverage.significant_line_count,
       readiness.parsed_percent,
       readiness.fact_backed_percent,
       readiness.unparsed_line_count,
       readiness.remaining_count,
       coalesce((select count(*)
                 from repo_asm_include_edge_fact include_edge
                 join repo_file source_file on source_file.path = include_edge.source_path
                 where include_edge.target_path = repo_file.path
                   and source_file.file_kind = 'asm'), 0) as inbound_text_include_count,
       coalesce((select count(*)
                 from repo_asm_binary_include_dependency_fact binary_include
                 where binary_include.path = repo_file.path), 0) as binary_include_dependency_count,
       case
         when repo_file.file_kind = 'source_object_asm' and readiness.remaining_count = 0 then 'text_deleted_fact_backed'
         when repo_file.file_kind = 'asm'
          and readiness.remaining_count = 0
          and coalesce((select count(*)
                        from repo_asm_include_edge_fact include_edge
                        join repo_file source_file on source_file.path = include_edge.source_path
                        where include_edge.target_path = repo_file.path
                          and source_file.file_kind = 'asm'), 0) > 0 then 'blocked_by_inbound_text_include'
         when repo_file.file_kind = 'asm'
          and readiness.remaining_count = 0
          and coalesce((select count(*)
                        from repo_asm_binary_include_dependency_fact binary_include
                        where binary_include.path = repo_file.path), 0) > 0 then 'blocked_by_object_materialization_dependency'
         when repo_file.file_kind = 'asm' and readiness.remaining_count = 0 then 'ready_to_wrap_and_delete_text'
         when readiness.unparsed_line_count > 0 then 'blocked_by_parse_coverage'
         else 'blocked_by_fact_gaps'
       end as deletion_state,
       case
         when repo_file.file_kind = 'asm' then repo_file.path || '.erobj'
         else repo_file.path
       end as source_object_path,
       exists (
         select 1
         from repo_file source_object
         where source_object.path = repo_file.path || '.erobj'
       ) as source_object_exists
from repo_asm_deletion_readiness readiness
join repo_file using (path)
join repo_asm_parse_coverage coverage using (path)
where repo_file.file_kind in ('asm', 'source_object_asm')
order by
  case deletion_state
    when 'ready_to_wrap_and_delete_text' then 0
    when 'blocked_by_fact_gaps' then 1
    when 'blocked_by_parse_coverage' then 2
    else 3
  end,
  remaining_count,
  byte_len desc;

create unique index repo_asm_source_deletion_plan_path_idx on repo_asm_source_deletion_plan(path);
create index repo_asm_source_deletion_plan_state_idx on repo_asm_source_deletion_plan(deletion_state, remaining_count, byte_len);

create table repo_asm_gap_delete_impact as
with per_gap_file as (
  select path,
         gap_kind,
         op_name,
         coalesce(operand_text, '') as operand_text,
         count(*) as gap_count_in_file
  from repo_asm_remaining_meaning_gap
  group by path, gap_kind, op_name, coalesce(operand_text, '')
)
select gap_kind,
       op_name,
       operand_text,
       count(*) as impacted_file_count,
       sum(repo_file.byte_len) as impacted_bytes,
       sum(gap_count_in_file) as occurrence_count,
       sum(case when plan.remaining_count = gap_count_in_file then 1 else 0 end) as full_unlock_file_count,
       sum(case when plan.remaining_count = gap_count_in_file then repo_file.byte_len else 0 end) as full_unlock_bytes,
       min(plan.remaining_count - gap_count_in_file) as min_remaining_after_gap
from per_gap_file
join repo_asm_source_deletion_plan plan using (path)
join repo_file using (path)
where plan.deletion_state in ('blocked_by_parse_coverage', 'blocked_by_fact_gaps')
group by gap_kind, op_name, operand_text
order by full_unlock_bytes desc, impacted_bytes desc, occurrence_count desc;

create index repo_asm_gap_delete_impact_unlock_idx on repo_asm_gap_delete_impact(full_unlock_bytes, impacted_bytes);
create index repo_asm_gap_delete_impact_gap_idx on repo_asm_gap_delete_impact(gap_kind, op_name, operand_text);

create table repo_asm_gap_example as
select path,
       line_no,
       gap_kind,
       op_name,
       operand_text,
       raw_text,
       row_number() over (
         partition by gap_kind, op_name, operand_text
         order by path, line_no
       ) as example_rank
from repo_asm_remaining_gap;

create index repo_asm_gap_example_gap_idx on repo_asm_gap_example(gap_kind, op_name, operand_text, example_rank);

create table repo_asm_gap_operand_text as
select path,
       repo_file_id,
       function_name,
       line_no,
       op_name,
       operand_text,
       ' ' || replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(operand_text,
         ',', ' '), '[', ' '), ']', ' '), '+', ' '), '-', ' '), '*', ' '), '/', ' '), '(', ' '), ')', ' '), ':', ' ') || ' ' as normalized_operand_text
from repo_asm_remaining_gap
where gap_kind = 'known_gap'
  and operand_text is not null;

create index repo_asm_gap_operand_text_line_idx on repo_asm_gap_operand_text(repo_file_id, function_name, line_no);

create table repo_asm_unresolved_constant_symbol_gap as
select symbol.symbol_name,
       symbol.reason,
       count(token.line_no) as occurrence_count,
       count(distinct token.path) as file_count,
       count(distinct token.function_name) as function_count,
       min(token.path) as example_path,
       min(token.line_no) as example_line_no,
       max(case when definition.symbol_name is null then 1 else 0 end) as missing_definition,
       count(distinct definition.expression_text) as expression_count,
       group_concat(distinct definition.expression_text) as expression_examples
from asm_constant_expression_symbol_fact symbol
left join repo_asm_constant_definition_fact definition
  on definition.symbol_name = symbol.symbol_name
left join repo_asm_gap_operand_text token
  on token.normalized_operand_text like '% ' || symbol.symbol_name || ' %'
where symbol.symbol_name not in (select symbol_name from repo_asm_unique_constant_fact)
group by symbol.symbol_name, symbol.reason
having occurrence_count > 0
order by occurrence_count desc, file_count desc, symbol.symbol_name;

create index repo_asm_unresolved_constant_symbol_gap_occurrence_idx
  on repo_asm_unresolved_constant_symbol_gap(occurrence_count, file_count);

create table repo_asm_next_operator_action as
select 0 as action_rank,
       'wrap_delete_ready_source' as action_kind,
       'Wrap and delete ready text source' as action_name,
       path,
       null as line_no,
       null as gap_kind,
       null as op_name,
       null as operand_text,
       byte_len as impacted_bytes,
       1 as impacted_file_count,
       1 as full_unlock_file_count,
       byte_len as full_unlock_bytes,
       remaining_count,
       'file-to-object ' || path || ' ' || source_object_path as action_hint,
       'Planner reports zero remaining blockers for tracked text source.' as rationale
from repo_asm_source_deletion_plan
where deletion_state = 'ready_to_wrap_and_delete_text'
union all
select 10 + row_number() over (
         order by impact.full_unlock_bytes desc,
                  impact.impacted_bytes desc,
                  impact.occurrence_count desc,
                  impact.gap_kind,
                  impact.op_name,
                  impact.operand_text
       ) as action_rank,
       'close_full_unlock_gap' as action_kind,
       'Lower gap that fully unlocks source files' as action_name,
       example.path,
       example.line_no,
       impact.gap_kind,
       impact.op_name,
       impact.operand_text,
       impact.impacted_bytes,
       impact.impacted_file_count,
       impact.full_unlock_file_count,
       impact.full_unlock_bytes,
       impact.min_remaining_after_gap as remaining_count,
       case
         when impact.gap_kind = 'known_gap' then impact.op_name || ' ' || impact.operand_text
         else impact.gap_kind || ':' || impact.op_name || ' ' || impact.operand_text
       end as action_hint,
       'This gap class is sufficient to make at least one source file deletion-ready.' as rationale
from repo_asm_gap_delete_impact impact
left join repo_asm_gap_example example
  on example.gap_kind = impact.gap_kind
 and example.op_name = impact.op_name
 and example.operand_text = impact.operand_text
 and example.example_rank = 1
where impact.full_unlock_file_count > 0
union all
select 100 + row_number() over (
         order by occurrence_count desc,
                  file_count desc,
                  symbol_name
       ) as action_rank,
       'resolve_constant_fact_gap' as action_kind,
       'Resolve unresolved high-impact constant fact' as action_name,
       example_path as path,
       example_line_no as line_no,
       'known_gap' as gap_kind,
       '' as op_name,
       symbol_name as operand_text,
       0 as impacted_bytes,
       file_count as impacted_file_count,
       0 as full_unlock_file_count,
       0 as full_unlock_bytes,
       occurrence_count as remaining_count,
       symbol_name || ' definitions=' || expression_count as action_hint,
       case
         when missing_definition = 1 then 'High-impact constant has no imported definition fact.'
         else 'High-impact constant has conflicting imported definition facts.'
       end as rationale
from repo_asm_unresolved_constant_symbol_gap
union all
select 500 + row_number() over (
         order by plan.remaining_count asc,
                  plan.byte_len desc,
                  gap.path,
                  gap.line_no
       ) as action_rank,
       'lower_near_ready_gap' as action_kind,
       'Lower gap blocking a near-ready source file' as action_name,
       gap.path,
       gap.line_no,
       gap.gap_kind,
       gap.op_name,
       gap.operand_text,
       plan.byte_len as impacted_bytes,
       1 as impacted_file_count,
       1 as full_unlock_file_count,
       case when plan.remaining_count = 1 then plan.byte_len else 0 end as full_unlock_bytes,
       plan.remaining_count,
       case
         when gap.gap_kind = 'known_gap' then gap.op_name || ' ' || coalesce(gap.operand_text, '')
         else gap.gap_kind || ':' || gap.op_name || ' ' || coalesce(gap.operand_text, '')
       end as action_hint,
       'This exact remaining gap belongs to a file with eight or fewer blockers.' as rationale
from repo_asm_remaining_gap gap
join repo_asm_source_deletion_plan plan using (path)
where plan.deletion_state = 'blocked_by_fact_gaps'
  and plan.remaining_count <= 8
union all
select 1000 + row_number() over (order by remaining_count asc, byte_len desc, path) as action_rank,
       'inspect_near_ready_file' as action_kind,
       'Inspect near-ready source file gaps' as action_name,
       path,
       null as line_no,
       null as gap_kind,
       null as op_name,
       null as operand_text,
       byte_len as impacted_bytes,
       1 as impacted_file_count,
       0 as full_unlock_file_count,
       0 as full_unlock_bytes,
       remaining_count,
       'remaining gaps for ' || path as action_hint,
       'Small remaining gap count can expose targeted file deletion opportunities.' as rationale
from repo_asm_source_deletion_plan
where deletion_state = 'blocked_by_fact_gaps'
  and remaining_count <= 8
union all
select 2000 + row_number() over (
         order by impact.impacted_bytes desc,
                  impact.occurrence_count desc,
                  impact.gap_kind,
                  impact.op_name,
                  impact.operand_text
       ) as action_rank,
       'lower_high_impact_gap' as action_kind,
       'Lower highest-impact remaining gap' as action_name,
       example.path,
       example.line_no,
       impact.gap_kind,
       impact.op_name,
       impact.operand_text,
       impact.impacted_bytes,
       impact.impacted_file_count,
       impact.full_unlock_file_count,
       impact.full_unlock_bytes,
       impact.min_remaining_after_gap as remaining_count,
       case
         when impact.gap_kind = 'known_gap' then impact.op_name || ' ' || impact.operand_text
         else impact.gap_kind || ':' || impact.op_name || ' ' || impact.operand_text
       end as action_hint,
       'Largest byte impact among remaining blockers after immediate unlocks and near-ready files.' as rationale
from repo_asm_gap_delete_impact impact
left join repo_asm_gap_example example
  on example.gap_kind = impact.gap_kind
 and example.op_name = impact.op_name
 and example.operand_text = impact.operand_text
 and example.example_rank = 1
where impact.full_unlock_file_count = 0;

create index repo_asm_next_operator_action_rank_idx on repo_asm_next_operator_action(action_rank);
create index repo_asm_next_operator_action_kind_idx on repo_asm_next_operator_action(action_kind, action_rank);

create view repo_asm_operator_dashboard as
select 'status:' || fact_status as metric,
       count(*) as value
from repo_asm_operation_fact_status
group by fact_status
union all
select 'next_action:' || action_kind,
       count(*)
from repo_asm_next_operator_action
group by action_kind
union all
select 'unresolved_high_impact_constants',
       count(*)
from repo_asm_unresolved_constant_symbol_gap
union all
select 'deletion_state:' || deletion_state,
       count(*)
from repo_asm_source_deletion_plan
group by deletion_state
order by metric;

-- Universal transformer substrate. Domain tables above remain compact authoring
-- views; these relations prove that unrelated domains can lower through the
-- same rule application and byte materialization path.
create table universal_entity_kind (
  kind_id integer primary key,
  name text not null unique
);

insert into universal_entity_kind(kind_id, name) values
  (1, 'request'),
  (2, 'header'),
  (3, 'method'),
  (4, 'target'),
  (5, 'version'),
  (6, 'operation'),
  (7, 'function'),
  (8, 'value'),
  (9, 'instruction'),
  (10, 'operand'),
  (11, 'byte_chunk'),
  (12, 'object'),
  (13, 'receipt');

create table universal_entity (
  entity_id integer primary key,
  kind_id integer not null references universal_entity_kind(kind_id),
  stable_name text not null unique,
  literal_text text,
  literal_integer integer,
  object_path text
);

create table universal_edge_kind (
  edge_kind_id integer primary key,
  name text not null unique
);

insert into universal_edge_kind(edge_kind_id, name) values
  (1, 'contains'),
  (2, 'has_method'),
  (3, 'has_target'),
  (4, 'has_version'),
  (5, 'has_header'),
  (6, 'has_value'),
  (7, 'has_operand'),
  (8, 'lowers_to'),
  (9, 'emits'),
  (10, 'requires'),
  (11, 'proves');

create table universal_edge (
  edge_id integer primary key,
  from_entity_id integer not null references universal_entity(entity_id),
  to_entity_id integer not null references universal_entity(entity_id),
  edge_kind_id integer not null references universal_edge_kind(edge_kind_id),
  sequence integer not null default 0,
  role text not null default '',
  unique (from_entity_id, to_entity_id, edge_kind_id, sequence, role)
);

create table universal_rule_kind (
  rule_kind_id integer primary key,
  name text not null unique
);

insert into universal_rule_kind(rule_kind_id, name) values
  (1, 'grammar'),
  (2, 'semantic'),
  (3, 'lowering'),
  (4, 'encoding'),
  (5, 'materialization'),
  (6, 'validation');

create table universal_rule (
  rule_id integer primary key,
  rule_kind_id integer not null references universal_rule_kind(rule_kind_id),
  name text not null unique,
  source_kind_id integer not null references universal_entity_kind(kind_id),
  target_kind_id integer not null references universal_entity_kind(kind_id),
  priority integer not null default 0,
  flags integer not null default 0
);

create table universal_rule_application (
  application_id integer primary key,
  rule_id integer not null references universal_rule(rule_id),
  source_entity_id integer not null references universal_entity(entity_id),
  output_entity_id integer not null references universal_entity(entity_id),
  sequence integer not null,
  status integer not null default 0,
  unique (rule_id, source_entity_id, output_entity_id, sequence)
);

create table universal_rule_byte (
  application_id integer not null references universal_rule_application(application_id),
  sequence integer not null,
  hex_bytes text not null,
  primary key (application_id, sequence)
);

create table universal_requirement (
  requirement_id integer primary key,
  entity_id integer not null references universal_entity(entity_id),
  requirement_kind text not null,
  requirement_value text not null,
  unique (entity_id, requirement_kind, requirement_value)
);

insert into universal_rule(rule_id, rule_kind_id, name, source_kind_id, target_kind_id, priority, flags) values
  (1, 4, 'x86_64_const_i32_42_to_mov_eax_imm32', 6, 11, 10, 0),
  (2, 4, 'x86_64_return_value_to_ret', 6, 11, 10, 0),
  (3, 4, 'x86_64_mov_rcx_rsi_exact', 6, 11, 10, 0),
  (4, 4, 'x86_64_sub_rcx_rdi_exact', 6, 11, 10, 0),
  (5, 4, 'x86_64_jle_done_rel8_10_exact', 6, 11, 10, 0),
  (6, 4, 'x86_64_xor_eax_eax_exact', 6, 11, 10, 0),
  (7, 4, 'x86_64_cld_exact', 6, 11, 10, 0),
  (8, 4, 'x86_64_shr_rcx_3_exact', 6, 11, 10, 0),
  (9, 4, 'x86_64_rep_stosq_exact', 6, 11, 10, 0),
  (10, 4, 'http_request_line_get_root_1_1', 1, 11, 10, 0),
  (11, 4, 'http_header_line_host_example_com', 2, 11, 10, 0),
  (12, 4, 'http_header_line_connection_close', 2, 11, 10, 0),
  (13, 4, 'http_header_section_end', 1, 11, 10, 0);

insert into universal_entity(entity_id, kind_id, stable_name, literal_text, literal_integer, object_path) values
  (1, 7, 'universal.return_42_x86_64', null, null, 'kernel/x86_64/object/function/return_42_x86_64.erobj'),
  (2, 6, 'universal.return_42.const_i32_42', 'const_i32', 42, null),
  (3, 6, 'universal.return_42.return_value', 'return_value', null, null),
  (4, 7, 'universal.er_bss_zero', null, null, 'kernel/test/test_flat_runtime.asm.erobj'),
  (5, 6, 'universal.er_bss_zero.mov_rcx_rsi', 'mov rcx, rsi', null, null),
  (6, 6, 'universal.er_bss_zero.sub_rcx_rdi', 'sub rcx, rdi', null, null),
  (7, 6, 'universal.er_bss_zero.jle_done', 'jle .done', null, null),
  (8, 6, 'universal.er_bss_zero.xor_eax_eax', 'xor eax, eax', null, null),
  (9, 6, 'universal.er_bss_zero.cld', 'cld', null, null),
  (10, 6, 'universal.er_bss_zero.shr_rcx_3', 'shr rcx, 3', null, null),
  (11, 6, 'universal.er_bss_zero.rep_stosq', 'rep stosq', null, null),
  (12, 6, 'universal.er_bss_zero.ret', 'ret', null, null),
  (20, 1, 'universal.http_request.example_get_root', null, null, null),
  (21, 3, 'universal.http_method.GET', 'GET', null, null),
  (22, 4, 'universal.http_target.root', '/', null, null),
  (23, 5, 'universal.http_version.1_1', 'HTTP/1.1', null, null),
  (24, 2, 'universal.http_header.Host.example_com', 'Host: example.com', null, null),
  (25, 2, 'universal.http_header.Connection.close', 'Connection: close', null, null),
  (100, 11, 'universal.bytes.return_42.mov_eax_42', null, null, null),
  (101, 11, 'universal.bytes.return_42.ret', null, null, null),
  (102, 11, 'universal.bytes.er_bss_zero.mov_rcx_rsi', null, null, null),
  (103, 11, 'universal.bytes.er_bss_zero.sub_rcx_rdi', null, null, null),
  (104, 11, 'universal.bytes.er_bss_zero.jle_done', null, null, null),
  (105, 11, 'universal.bytes.er_bss_zero.xor_eax_eax', null, null, null),
  (106, 11, 'universal.bytes.er_bss_zero.cld', null, null, null),
  (107, 11, 'universal.bytes.er_bss_zero.shr_rcx_3', null, null, null),
  (108, 11, 'universal.bytes.er_bss_zero.rep_stosq', null, null, null),
  (109, 11, 'universal.bytes.er_bss_zero.ret', null, null, null),
  (110, 11, 'universal.bytes.http.request_line', null, null, null),
  (111, 11, 'universal.bytes.http.header.host', null, null, null),
  (112, 11, 'universal.bytes.http.header.connection', null, null, null),
  (113, 11, 'universal.bytes.http.header_end', null, null, null);

insert into universal_edge(edge_id, from_entity_id, to_entity_id, edge_kind_id, sequence, role) values
  (1, 1, 2, 1, 1, 'operation'),
  (2, 1, 3, 1, 2, 'operation'),
  (3, 4, 5, 1, 1, 'operation'),
  (4, 4, 6, 1, 2, 'operation'),
  (5, 4, 7, 1, 3, 'operation'),
  (6, 4, 8, 1, 4, 'operation'),
  (7, 4, 9, 1, 5, 'operation'),
  (8, 4, 10, 1, 6, 'operation'),
  (9, 4, 11, 1, 7, 'operation'),
  (10, 4, 12, 1, 8, 'operation'),
  (11, 20, 21, 2, 1, 'method'),
  (12, 20, 22, 3, 2, 'target'),
  (13, 20, 23, 4, 3, 'version'),
  (14, 20, 24, 5, 4, 'header'),
  (15, 20, 25, 5, 5, 'header');

insert into universal_rule_application(application_id, rule_id, source_entity_id, output_entity_id, sequence, status) values
  (1, 1, 2, 100, 1, 0),
  (2, 2, 3, 101, 2, 0),
  (3, 3, 5, 102, 1, 0),
  (4, 4, 6, 103, 2, 0),
  (5, 5, 7, 104, 3, 0),
  (6, 6, 8, 105, 4, 0),
  (7, 7, 9, 106, 5, 0),
  (8, 8, 10, 107, 6, 0),
  (9, 9, 11, 108, 7, 0),
  (10, 2, 12, 109, 8, 0),
  (11, 10, 20, 110, 1, 0),
  (12, 11, 24, 111, 2, 0),
  (13, 12, 25, 112, 3, 0),
  (14, 13, 20, 113, 4, 0);

insert into universal_rule_byte(application_id, sequence, hex_bytes) values
  (1, 1, 'b82a000000'),
  (2, 1, 'c3'),
  (3, 1, '4889f1'),
  (4, 1, '4829f9'),
  (5, 1, '7e0a'),
  (6, 1, '31c0'),
  (7, 1, 'fc'),
  (8, 1, '48c1e903'),
  (9, 1, 'f348ab'),
  (10, 1, 'c3'),
  (11, 1, '474554202f20485454502f312e310d0a'),
  (12, 1, '486f73743a206578616d706c652e636f6d0d0a'),
  (13, 1, '436f6e6e656374696f6e3a20636c6f73650d0a'),
  (14, 1, '0d0a');

insert into universal_requirement(requirement_id, entity_id, requirement_kind, requirement_value) values
  (1, 20, 'http.version.requires_header', 'Host'),
  (2, 20, 'http.header_value.forbid_raw_crlf', 'true'),
  (3, 20, 'transport', 'none_materialization_only');

create view universal_rule_applications_expanded as
select universal_rule_application.application_id,
       universal_rule.name as rule_name,
       universal_rule_kind.name as rule_kind,
       source_entity.stable_name as source_entity,
       source_kind.name as source_kind,
       output_entity.stable_name as output_entity,
       output_kind.name as output_kind,
       universal_rule_application.sequence,
       universal_rule_application.status
from universal_rule_application
join universal_rule using (rule_id)
join universal_rule_kind using (rule_kind_id)
join universal_entity source_entity on source_entity.entity_id = universal_rule_application.source_entity_id
join universal_entity_kind source_kind on source_kind.kind_id = source_entity.kind_id
join universal_entity output_entity on output_entity.entity_id = universal_rule_application.output_entity_id
join universal_entity_kind output_kind on output_kind.kind_id = output_entity.kind_id;

create view universal_byte_chunks as
select root_entity.stable_name as root_name,
       universal_rule_application.sequence as application_sequence,
       universal_rule_byte.sequence as byte_sequence,
       universal_rule.name as rule_name,
       universal_rule_byte.hex_bytes
from universal_entity root_entity
join universal_edge contains_edge
  on contains_edge.from_entity_id = root_entity.entity_id
 and contains_edge.edge_kind_id = 1
join universal_rule_application
  on universal_rule_application.source_entity_id = contains_edge.to_entity_id
join universal_rule using (rule_id)
join universal_rule_byte using (application_id)
where root_entity.kind_id = 7
union all
select request_entity.stable_name as root_name,
       universal_rule_application.sequence as application_sequence,
       universal_rule_byte.sequence as byte_sequence,
       universal_rule.name as rule_name,
       universal_rule_byte.hex_bytes
from universal_entity request_entity
join universal_rule_application
  on universal_rule_application.source_entity_id = request_entity.entity_id
join universal_rule using (rule_id)
join universal_rule_byte using (application_id)
where request_entity.kind_id = 1
union all
select request_entity.stable_name as root_name,
       universal_rule_application.sequence as application_sequence,
       universal_rule_byte.sequence as byte_sequence,
       universal_rule.name as rule_name,
       universal_rule_byte.hex_bytes
from universal_entity request_entity
join universal_edge header_edge
  on header_edge.from_entity_id = request_entity.entity_id
 and header_edge.edge_kind_id = 5
join universal_rule_application
  on universal_rule_application.source_entity_id = header_edge.to_entity_id
join universal_rule using (rule_id)
join universal_rule_byte using (application_id)
where request_entity.kind_id = 1;

create view universal_flat_hex as
select root_name,
       group_concat(hex_bytes, '') as hex_bytes
from (
  select root_name, application_sequence, byte_sequence, hex_bytes
  from universal_byte_chunks
  order by root_name, application_sequence, byte_sequence
)
group by root_name;

create view universal_http_request_byte_chunks as
select request_entity.stable_name as root_name,
       1 as sequence,
       'http.method' as role,
       lower(hex(method_entity.literal_text)) as hex_bytes
from universal_entity request_entity
join universal_edge method_edge
  on method_edge.from_entity_id = request_entity.entity_id
 and method_edge.edge_kind_id = 2
join universal_entity method_entity on method_entity.entity_id = method_edge.to_entity_id
where request_entity.kind_id = 1
union all
select request_entity.stable_name, 2, 'http.sp.after_method', '20'
from universal_entity request_entity
where request_entity.kind_id = 1
union all
select request_entity.stable_name,
       3,
       'http.target',
       lower(hex(target_entity.literal_text))
from universal_entity request_entity
join universal_edge target_edge
  on target_edge.from_entity_id = request_entity.entity_id
 and target_edge.edge_kind_id = 3
join universal_entity target_entity on target_entity.entity_id = target_edge.to_entity_id
where request_entity.kind_id = 1
union all
select request_entity.stable_name, 4, 'http.sp.after_target', '20'
from universal_entity request_entity
where request_entity.kind_id = 1
union all
select request_entity.stable_name,
       5,
       'http.version',
       lower(hex(version_entity.literal_text))
from universal_entity request_entity
join universal_edge version_edge
  on version_edge.from_entity_id = request_entity.entity_id
 and version_edge.edge_kind_id = 4
join universal_entity version_entity on version_entity.entity_id = version_edge.to_entity_id
where request_entity.kind_id = 1
union all
select request_entity.stable_name, 6, 'http.request_line_crlf', '0d0a'
from universal_entity request_entity
where request_entity.kind_id = 1
union all
select request_entity.stable_name,
       100 + header_edge.sequence,
       'http.header',
       lower(hex(header_entity.literal_text)) || '0d0a'
from universal_entity request_entity
join universal_edge header_edge
  on header_edge.from_entity_id = request_entity.entity_id
 and header_edge.edge_kind_id = 5
join universal_entity header_entity on header_entity.entity_id = header_edge.to_entity_id
where request_entity.kind_id = 1
union all
select request_entity.stable_name,
       1000000,
       'http.header_section_end',
       '0d0a'
from universal_entity request_entity
where request_entity.kind_id = 1;

create view universal_http_request_flat_hex as
select root_name,
       group_concat(hex_bytes, '') as hex_bytes
from (
  select root_name, sequence, hex_bytes
  from universal_http_request_byte_chunks
  order by root_name, sequence
)
group by root_name;

create view universal_gap_summary as
select 'source_without_rule_application' as gap_kind,
       universal_entity_kind.name as entity_kind,
       count(*) as entity_count
from universal_entity
join universal_entity_kind using (kind_id)
left join universal_rule_application on universal_rule_application.source_entity_id = universal_entity.entity_id
where universal_entity.kind_id in (1, 2, 6)
  and universal_rule_application.application_id is null
group by universal_entity_kind.name;

insert into universal_entity_kind(kind_id, name) values
  (14, 'syscall'),
  (15, 'abi'),
  (16, 'register'),
  (17, 'data'),
  (18, 'symbol');

insert into universal_edge_kind(edge_kind_id, name) values
  (12, 'has_syscall_number'),
  (13, 'arg_in_register'),
  (14, 'returns_in'),
  (15, 'clobbers'),
  (16, 'has_data'),
  (17, 'has_symbol'),
  (18, 'has_length');

create table universal_register_fact (
  register_fact_id integer primary key,
  isa_id integer not null references isa(isa_id),
  name text not null,
  width_bits integer not null,
  parent_name text,
  encoding_index integer not null,
  object_path text,
  unique (isa_id, name)
);

insert into universal_register_fact(register_fact_id, isa_id, name, width_bits, parent_name, encoding_index, object_path) values
  (1, 1, 'rax', 64, null, 0, 'kernel/x86_64/object/register/x86_64/rax.erobj'),
  (2, 1, 'eax', 32, 'rax', 0, 'kernel/x86_64/object/register/x86_64/eax.erobj'),
  (3, 1, 'rdi', 64, null, 7, 'kernel/x86_64/object/register/x86_64/rdi.erobj'),
  (4, 1, 'edi', 32, 'rdi', 7, 'kernel/x86_64/object/register/x86_64/edi.erobj'),
  (5, 1, 'rsi', 64, null, 6, 'kernel/x86_64/object/register/x86_64/rsi.erobj'),
  (6, 1, 'esi', 32, 'rsi', 6, 'kernel/x86_64/object/register/x86_64/esi.erobj'),
  (7, 1, 'rdx', 64, null, 2, 'kernel/x86_64/object/register/x86_64/rdx.erobj'),
  (8, 1, 'edx', 32, 'rdx', 2, 'kernel/x86_64/object/register/x86_64/edx.erobj'),
  (9, 1, 'r10', 64, null, 10, 'kernel/x86_64/object/register/x86_64/r10.erobj'),
  (10, 1, 'r8', 64, null, 8, 'kernel/x86_64/object/register/x86_64/r8.erobj'),
  (11, 1, 'r9', 64, null, 9, 'kernel/x86_64/object/register/x86_64/r9.erobj'),
  (12, 1, 'rcx', 64, null, 1, 'kernel/x86_64/object/register/x86_64/rcx.erobj'),
  (13, 1, 'r11', 64, null, 11, 'kernel/x86_64/object/register/x86_64/r11.erobj');

create table linux_syscall_fact (
  syscall_id integer primary key,
  name text not null unique,
  number integer not null unique,
  arg_count integer not null,
  object_path text not null unique
);

insert into linux_syscall_fact(syscall_id, name, number, arg_count, object_path) values
  (1, 'write', 1, 3, 'kernel/x86_64/object/syscall/linux_x86_64/write.erobj'),
  (60, 'exit', 60, 1, 'kernel/x86_64/object/syscall/linux_x86_64/exit.erobj'),
  (231, 'exit_group', 231, 1, 'kernel/x86_64/object/syscall/linux_x86_64/exit_group.erobj');

create table linux_x86_64_syscall_abi_fact (
  abi_fact_id integer primary key,
  role text not null,
  arg_index integer,
  register_name text not null,
  unique (role, arg_index, register_name)
);

insert into linux_x86_64_syscall_abi_fact(abi_fact_id, role, arg_index, register_name) values
  (1, 'number', null, 'eax'),
  (2, 'return', null, 'rax'),
  (3, 'arg', 0, 'edi'),
  (4, 'arg', 1, 'rsi'),
  (5, 'arg', 2, 'edx'),
  (6, 'arg', 3, 'r10'),
  (7, 'arg', 4, 'r8'),
  (8, 'arg', 5, 'r9'),
  (9, 'clobber', null, 'rcx'),
  (10, 'clobber', null, 'r11');

create table x86_64_encoding_template_fact (
  template_id integer primary key,
  name text not null unique,
  operation_name text not null,
  operand_signature text not null,
  fixed_hex text not null,
  immediate_width_bits integer not null default 0,
  immediate_endian text not null default '',
  rule_name text not null unique
);

insert into x86_64_encoding_template_fact(template_id, name, operation_name, operand_signature, fixed_hex, immediate_width_bits, immediate_endian, rule_name) values
  (1, 'mov_eax_imm32', 'set_register_immediate', 'eax,imm32', 'b8', 32, 'little', 'encode_mov_eax_imm32'),
  (2, 'mov_edi_imm32', 'set_register_immediate', 'edi,imm32', 'bf', 32, 'little', 'encode_mov_edi_imm32'),
  (3, 'mov_edx_imm32', 'set_register_immediate', 'edx,imm32', 'ba', 32, 'little', 'encode_mov_edx_imm32'),
  (4, 'xor_edi_edi', 'zero_register', 'edi,edi', '31ff', 0, '', 'encode_xor_edi_edi'),
  (5, 'syscall', 'linux_syscall_trap', 'none', '0f05', 0, '', 'encode_syscall'),
  (6, 'lea_rsi_riprel32', 'load_symbol_address', 'rsi,riprel32', '488d35', 32, 'little', 'encode_lea_rsi_riprel32');

create table universal_syscall_program (
  program_entity_id integer primary key references universal_entity(entity_id),
  name text not null unique,
  isa_id integer not null references isa(isa_id),
  abi_name text not null,
  entry_kind text not null
);

create table universal_syscall_program_step (
  program_entity_id integer not null references universal_syscall_program(program_entity_id),
  sequence integer not null,
  operation_name text not null,
  syscall_name text,
  arg_index integer,
  register_name text,
  literal_integer integer,
  symbol_name text,
  primary key (program_entity_id, sequence)
);

create table universal_data_fact (
  data_entity_id integer primary key references universal_entity(entity_id),
  symbol_name text not null unique,
  hex_bytes text not null,
  byte_len integer not null
);

insert into universal_entity(entity_id, kind_id, stable_name, literal_text, literal_integer, object_path) values
  (200, 7, 'universal.linux_exit_group_0', null, null, null),
  (201, 7, 'universal.linux_write_hi_exit', null, null, null),
  (202, 17, 'universal.data.msg_hi_newline', 'hi\n', null, null),
  (203, 14, 'universal.syscall.write', 'write', 1, 'kernel/x86_64/object/syscall/linux_x86_64/write.erobj'),
  (204, 14, 'universal.syscall.exit_group', 'exit_group', 231, 'kernel/x86_64/object/syscall/linux_x86_64/exit_group.erobj'),
  (205, 15, 'universal.abi.linux_x86_64_syscall', 'linux_x86_64_syscall', null, null);

insert into universal_data_fact(data_entity_id, symbol_name, hex_bytes, byte_len) values
  (202, 'msg_hi_newline', '68690a', 3);

insert into universal_edge(edge_id, from_entity_id, to_entity_id, edge_kind_id, sequence, role) values
  (100, 201, 202, 16, 1, 'data'),
  (101, 200, 204, 10, 1, 'syscall'),
  (102, 201, 203, 10, 1, 'syscall'),
  (103, 201, 204, 10, 2, 'syscall'),
  (104, 200, 205, 10, 1, 'abi'),
  (105, 201, 205, 10, 1, 'abi');

insert into universal_syscall_program(program_entity_id, name, isa_id, abi_name, entry_kind) values
  (200, 'linux_exit_group_0', 1, 'linux_x86_64_syscall', 'flat_bytes'),
  (201, 'linux_write_hi_exit', 1, 'linux_x86_64_syscall', 'flat_bytes');

insert into universal_syscall_program_step(program_entity_id, sequence, operation_name, syscall_name, arg_index, register_name, literal_integer, symbol_name) values
  (200, 1, 'set_syscall_number', 'exit_group', null, null, null, null),
  (200, 2, 'zero_register', null, 0, 'edi', 0, null),
  (200, 3, 'linux_syscall_trap', null, null, null, null, null),
  (201, 1, 'set_syscall_number', 'write', null, null, null, null),
  (201, 2, 'set_arg_immediate', null, 0, null, 1, null),
  (201, 3, 'set_arg_symbol_address', null, 1, null, null, 'msg_hi_newline'),
  (201, 4, 'set_arg_immediate', null, 2, null, 3, null),
  (201, 5, 'linux_syscall_trap', null, null, null, null, null),
  (201, 6, 'set_syscall_number', 'exit_group', null, null, null, null),
  (201, 7, 'zero_register', null, 0, 'edi', 0, null),
  (201, 8, 'linux_syscall_trap', null, null, null, null, null);

create view universal_syscall_program_resolved_steps as
select step.program_entity_id,
       program.name as program_name,
       step.sequence,
       step.operation_name,
       step.syscall_name,
       syscall.number as syscall_number,
       step.arg_index,
       coalesce(step.register_name, abi_arg.register_name) as register_name,
       step.literal_integer,
       step.symbol_name,
       data_fact.hex_bytes as data_hex,
       data_fact.byte_len as data_byte_len
from universal_syscall_program_step step
join universal_syscall_program program using (program_entity_id)
left join linux_syscall_fact syscall on syscall.name = step.syscall_name
left join linux_x86_64_syscall_abi_fact abi_arg
  on abi_arg.role = 'arg'
 and abi_arg.arg_index = step.arg_index
left join universal_data_fact data_fact on data_fact.symbol_name = step.symbol_name;

create view universal_syscall_program_gap_summary as
select 'unknown_syscall' as gap_kind, program_name, sequence, syscall_name as subject
from universal_syscall_program_resolved_steps
where syscall_name is not null and syscall_number is null
union all
select 'unknown_arg_register', program_name, sequence, cast(arg_index as text)
from universal_syscall_program_resolved_steps
where operation_name in ('set_arg_immediate', 'set_arg_symbol_address')
  and register_name is null
union all
select 'unknown_symbol', program_name, sequence, symbol_name
from universal_syscall_program_resolved_steps
where symbol_name is not null and data_hex is null;

create view universal_syscall_program_code_chunk_templates as
select program_name,
       sequence,
       'mov_eax_syscall_number' as rule_name,
       5 as byte_len,
       null as symbol_name,
       (select fixed_hex from x86_64_encoding_template_fact where name = 'mov_eax_imm32') ||
       printf('%02x%02x%02x%02x', syscall_number & 255, (syscall_number >> 8) & 255, (syscall_number >> 16) & 255, (syscall_number >> 24) & 255) as hex_bytes
from universal_syscall_program_resolved_steps
where operation_name = 'set_syscall_number'
union all
select program_name,
       sequence,
       'mov_edi_arg0_imm32',
       5,
       null,
       (select fixed_hex from x86_64_encoding_template_fact where name = 'mov_edi_imm32') ||
       printf('%02x%02x%02x%02x', literal_integer & 255, (literal_integer >> 8) & 255, (literal_integer >> 16) & 255, (literal_integer >> 24) & 255)
from universal_syscall_program_resolved_steps
where operation_name = 'set_arg_immediate'
  and arg_index = 0
union all
select program_name,
       sequence,
       'mov_edx_arg2_imm32',
       5,
       null,
       (select fixed_hex from x86_64_encoding_template_fact where name = 'mov_edx_imm32') ||
       printf('%02x%02x%02x%02x', literal_integer & 255, (literal_integer >> 8) & 255, (literal_integer >> 16) & 255, (literal_integer >> 24) & 255)
from universal_syscall_program_resolved_steps
where operation_name = 'set_arg_immediate'
  and arg_index = 2
union all
select program_name,
       sequence,
       'lea_rsi_symbol_riprel32',
       7,
       symbol_name,
       null
from universal_syscall_program_resolved_steps
where operation_name = 'set_arg_symbol_address'
  and arg_index = 1
union all
select program_name,
       sequence,
       'xor_edi_edi',
       2,
       null,
       (select fixed_hex from x86_64_encoding_template_fact where name = 'xor_edi_edi')
from universal_syscall_program_resolved_steps
where operation_name = 'zero_register'
  and register_name = 'edi'
union all
select program_name,
       sequence,
       'syscall',
       2,
       null,
       (select fixed_hex from x86_64_encoding_template_fact where name = 'syscall')
from universal_syscall_program_resolved_steps
where operation_name = 'linux_syscall_trap';

create view universal_syscall_program_code_layout as
select chunk.program_name,
       chunk.sequence,
       chunk.rule_name,
       chunk.byte_len,
       chunk.symbol_name,
       chunk.hex_bytes,
       coalesce((select sum(prev.byte_len)
                 from universal_syscall_program_code_chunk_templates prev
                 where prev.program_name = chunk.program_name
                   and prev.sequence < chunk.sequence), 0) as byte_offset,
       (select sum(all_chunks.byte_len)
        from universal_syscall_program_code_chunk_templates all_chunks
        where all_chunks.program_name = chunk.program_name) as code_byte_len
from universal_syscall_program_code_chunk_templates chunk;

create view universal_syscall_program_byte_chunks as
select program_name,
       sequence,
       byte_offset,
       rule_name,
       case
         when symbol_name is null then hex_bytes
         else (select fixed_hex from x86_64_encoding_template_fact where name = 'lea_rsi_riprel32') ||
              printf('%02x%02x%02x%02x',
                (code_byte_len - (byte_offset + byte_len)) & 255,
                ((code_byte_len - (byte_offset + byte_len)) >> 8) & 255,
                ((code_byte_len - (byte_offset + byte_len)) >> 16) & 255,
                ((code_byte_len - (byte_offset + byte_len)) >> 24) & 255)
       end as hex_bytes
from universal_syscall_program_code_layout
union all
select program.name,
       1000000 + row_number() over (partition by program.name order by data_fact.symbol_name),
       code_size.code_byte_len + coalesce((select sum(prev_data.byte_len)
                                           from universal_data_fact prev_data
                                           where prev_data.symbol_name < data_fact.symbol_name), 0),
       'data_' || data_fact.symbol_name,
       data_fact.hex_bytes
from universal_syscall_program program
join universal_edge data_edge
  on data_edge.from_entity_id = program.program_entity_id
 and data_edge.edge_kind_id = 16
join universal_data_fact data_fact on data_fact.data_entity_id = data_edge.to_entity_id
join (select program_name, max(code_byte_len) as code_byte_len
      from universal_syscall_program_code_layout
      group by program_name) code_size on code_size.program_name = program.name;

create view universal_syscall_program_flat_hex as
select program_name,
       group_concat(hex_bytes, '') as hex_bytes
from (
  select program_name, sequence, hex_bytes
  from universal_syscall_program_byte_chunks
  order by program_name, sequence
)
group by program_name;

-- Browser specification fact import. These are input facts only: checked browser
-- catalogs and parser IR are loaded as relations so the universal transformer can
-- operate on spec rows instead of generated browser implementation code.
create table browser_spec_source (
  source_id integer primary key,
  namespace text not null unique,
  path text not null unique,
  format text not null,
  byte_len integer not null,
  content blob not null
);

insert into browser_spec_source(source_id, namespace, path, format, byte_len, content) values
  (1, 'html.tokenizer', '/home/ken/edgerun-browser/data/tokenizer.textproto', 'textproto', length(readfile('/home/ken/edgerun-browser/data/tokenizer.textproto')), readfile('/home/ken/edgerun-browser/data/tokenizer.textproto')),
  (2, 'html.tree_builder', '/home/ken/edgerun-browser/data/tree_builder.textproto', 'textproto', length(readfile('/home/ken/edgerun-browser/data/tree_builder.textproto')), readfile('/home/ken/edgerun-browser/data/tree_builder.textproto')),
  (3, 'html.entities', '/home/ken/edgerun-browser/data/entities.textproto', 'textproto', length(readfile('/home/ken/edgerun-browser/data/entities.textproto')), readfile('/home/ken/edgerun-browser/data/entities.textproto')),
  (4, 'html.elements', '/home/ken/edgerun-browser/scripts/html_element_catalog.json', 'json', length(readfile('/home/ken/edgerun-browser/scripts/html_element_catalog.json')), readfile('/home/ken/edgerun-browser/scripts/html_element_catalog.json')),
  (5, 'css.properties', '/home/ken/edgerun-browser/scripts/css_property_catalog.json', 'json', length(readfile('/home/ken/edgerun-browser/scripts/css_property_catalog.json')), readfile('/home/ken/edgerun-browser/scripts/css_property_catalog.json')),
  (6, 'css.selectors', '/home/ken/edgerun-browser/scripts/selector_catalog.json', 'json', length(readfile('/home/ken/edgerun-browser/scripts/selector_catalog.json')), readfile('/home/ken/edgerun-browser/scripts/selector_catalog.json')),
  (7, 'fetch', '/home/ken/edgerun-browser/scripts/fetch_catalog.json', 'json', length(readfile('/home/ken/edgerun-browser/scripts/fetch_catalog.json')), readfile('/home/ken/edgerun-browser/scripts/fetch_catalog.json')),
  (8, 'url', '/home/ken/edgerun-browser/scripts/url_catalog.json', 'json', length(readfile('/home/ken/edgerun-browser/scripts/url_catalog.json')), readfile('/home/ken/edgerun-browser/scripts/url_catalog.json')),
  (9, 'encoding', '/home/ken/edgerun-browser/scripts/encoding_catalog.json', 'json', length(readfile('/home/ken/edgerun-browser/scripts/encoding_catalog.json')), readfile('/home/ken/edgerun-browser/scripts/encoding_catalog.json')),
  (10, 'ecmascript', '/home/ken/edgerun-browser/scripts/ecmascript_catalog.json', 'json', length(readfile('/home/ken/edgerun-browser/scripts/ecmascript_catalog.json')), readfile('/home/ken/edgerun-browser/scripts/ecmascript_catalog.json')),
  (11, 'dom', '/home/ken/edgerun-browser/scripts/dom_catalog.json', 'json', length(readfile('/home/ken/edgerun-browser/scripts/dom_catalog.json')), readfile('/home/ken/edgerun-browser/scripts/dom_catalog.json')),
  (12, 'render_ir.proto', '/home/ken/edgerun-browser/proto/edgerun/v0/ui/render_ir.proto', 'proto', length(readfile('/home/ken/edgerun-browser/proto/edgerun/v0/ui/render_ir.proto')), readfile('/home/ken/edgerun-browser/proto/edgerun/v0/ui/render_ir.proto'));

create table browser_spec_source_line (
  source_id integer not null references browser_spec_source(source_id),
  line_no integer not null,
  text text not null,
  primary key (source_id, line_no)
);

with recursive lines(source_id, line_no, rest, line) as (
  select source_id, 1, replace(cast(content as text), char(13), '') || char(10), ''
  from browser_spec_source
  where format in ('textproto', 'proto')
  union all
  select source_id,
         line_no + 1,
         substr(rest, instr(rest, char(10)) + 1),
         substr(rest, 1, instr(rest, char(10)) - 1)
  from lines
  where rest <> '' and instr(rest, char(10)) > 0
)
insert into browser_spec_source_line(source_id, line_no, text)
select source_id, line_no - 1, line
from lines
where line_no > 1;

create table browser_html_tokenizer_transition (
  transition_id integer primary key,
  current_state text not null,
  char_class text not null,
  next_state text not null,
  spec_section text not null,
  unique (current_state, char_class, transition_id)
);

create table browser_html_tokenizer_action (
  transition_id integer not null references browser_html_tokenizer_transition(transition_id),
  sequence integer not null,
  action_name text not null,
  action_value text not null,
  primary key (transition_id, sequence)
);

with tokenizer_lines as (
  select line_no,
         trim(text) as text,
         sum(case when trim(text) = 'transitions: {' then 1 else 0 end)
           over (order by line_no rows unbounded preceding) as transition_id
  from browser_spec_source_line
  where source_id = 1
), transition_rows as (
  select transition_id,
         max(case when text like 'current_state:%' then trim(substr(text, instr(text, ':') + 1)) end) as current_state,
         max(case when text like 'char_class:%' then trim(substr(text, instr(text, ':') + 1)) end) as char_class,
         max(case when text like 'next_state:%' then trim(substr(text, instr(text, ':') + 1)) end) as next_state,
         max(case when text like 'spec_section:%' then replace(trim(substr(text, instr(text, ':') + 1)), '"', '') end) as spec_section
  from tokenizer_lines
  where transition_id > 0
  group by transition_id
)
insert into browser_html_tokenizer_transition(transition_id, current_state, char_class, next_state, spec_section)
select transition_id, current_state, char_class, next_state, coalesce(spec_section, '')
from transition_rows
where current_state is not null and char_class is not null and next_state is not null;

with tokenizer_lines as (
  select line_no,
         trim(text) as text,
         sum(case when trim(text) = 'transitions: {' then 1 else 0 end)
           over (order by line_no rows unbounded preceding) as transition_id
  from browser_spec_source_line
  where source_id = 1
), action_lines as (
  select transition_id,
         line_no,
         substr(text, 1, instr(text, ':') - 1) as action_name,
         trim(substr(text, instr(text, ':') + 1)) as action_value
  from tokenizer_lines
  where transition_id > 0
    and instr(text, ':') > 0
    and text not like 'current_state:%'
    and text not like 'char_class:%'
    and text not like 'next_state:%'
    and text not like 'spec_section:%'
    and text not in ('transitions: {', 'actions: {', '}')
)
insert into browser_html_tokenizer_action(transition_id, sequence, action_name, action_value)
select transition_id,
       row_number() over (partition by transition_id order by line_no),
       action_name,
       replace(action_value, '"', '')
from action_lines;

create table browser_html_tree_rule (
  tree_rule_id integer primary key,
  mode text not null,
  trigger_kind text not null,
  trigger_value text not null,
  next_mode text not null,
  otherwise_flag integer not null default 0,
  pop_until_tag text,
  spec_paragraph text not null
);

create table browser_html_tree_rule_action (
  tree_rule_id integer not null references browser_html_tree_rule(tree_rule_id),
  sequence integer not null,
  action_name text not null,
  primary key (tree_rule_id, sequence)
);

with tree_lines as (
  select line_no,
         trim(text) as text,
         sum(case when trim(text) = 'rules: {' then 1 else 0 end)
           over (order by line_no rows unbounded preceding) as rule_id
  from browser_spec_source_line
  where source_id = 2
), rule_rows as (
  select rule_id,
         max(case when text like 'mode:%' then trim(substr(text, instr(text, ':') + 1)) end) as mode,
         max(case when text like 'token_type:%' then 'token_type'
                  when text like 'start_tag:%' then 'start_tag'
                  when text like 'end_tag:%' then 'end_tag'
                  when text like 'any_start_tag:%' then 'any_start_tag'
                  when text like 'any_end_tag:%' then 'any_end_tag'
                  when text like 'character_token:%' then 'character_token'
                  when text like 'whitespace_character:%' then 'whitespace_character' end) as trigger_kind,
         max(case when text like 'token_type:%' then trim(substr(text, instr(text, ':') + 1))
                  when text like 'start_tag:%' then replace(trim(substr(text, instr(text, ':') + 1)), '"', '')
                  when text like 'end_tag:%' then replace(trim(substr(text, instr(text, ':') + 1)), '"', '')
                  when text like 'any_start_tag:%' then trim(substr(text, instr(text, ':') + 1))
                  when text like 'any_end_tag:%' then trim(substr(text, instr(text, ':') + 1))
                  when text like 'character_token:%' then trim(substr(text, instr(text, ':') + 1))
                  when text like 'whitespace_character:%' then trim(substr(text, instr(text, ':') + 1)) end) as trigger_value,
         max(case when text like 'next_mode:%' then trim(substr(text, instr(text, ':') + 1)) end) as next_mode,
         max(case when text like 'otherwise:%' and trim(substr(text, instr(text, ':') + 1)) = 'true' then 1 else 0 end) as otherwise_flag,
         max(case when text like 'pop_until_tag:%' then replace(trim(substr(text, instr(text, ':') + 1)), '"', '') end) as pop_until_tag,
         max(case when text like 'spec_paragraph:%' then replace(trim(substr(text, instr(text, ':') + 1)), '"', '') end) as spec_paragraph
  from tree_lines
  where rule_id > 0
  group by rule_id
)
insert into browser_html_tree_rule(tree_rule_id, mode, trigger_kind, trigger_value, next_mode, otherwise_flag, pop_until_tag, spec_paragraph)
select rule_id,
       mode,
       coalesce(trigger_kind, 'unspecified'),
       coalesce(trigger_value, ''),
       coalesce(next_mode, ''),
       otherwise_flag,
       pop_until_tag,
       coalesce(spec_paragraph, '')
from rule_rows
where mode is not null;

with tree_lines as (
  select line_no,
         trim(text) as text,
         sum(case when trim(text) = 'rules: {' then 1 else 0 end)
           over (order by line_no rows unbounded preceding) as rule_id
  from browser_spec_source_line
  where source_id = 2
), action_lines as (
  select rule_id,
         line_no,
         trim(substr(text, instr(text, ':') + 1)) as action_name
  from tree_lines
  where rule_id > 0 and text like 'actions:%'
)
insert into browser_html_tree_rule_action(tree_rule_id, sequence, action_name)
select rule_id,
       row_number() over (partition by rule_id order by line_no),
       action_name
from action_lines;

create table browser_html_named_entity (
  entity_id integer primary key,
  name text not null unique,
  code_point_1 integer not null,
  code_point_2 integer not null default 0,
  semicolon_required integer not null
);

with entity_lines as (
  select line_no,
         trim(text) as text,
         sum(case when trim(text) = 'entities: {' then 1 else 0 end)
           over (order by line_no rows unbounded preceding) as entity_id
  from browser_spec_source_line
  where source_id = 3
), entity_rows as (
  select entity_id,
         max(case when text like 'name:%' then replace(trim(substr(text, instr(text, ':') + 1)), '"', '') end) as name,
         max(case when text like 'code_point_1:%' then cast(trim(substr(text, instr(text, ':') + 1)) as integer) end) as code_point_1,
         max(case when text like 'code_point_2:%' then cast(trim(substr(text, instr(text, ':') + 1)) as integer) end) as code_point_2,
         max(case when text like 'semicolon_required:%' then case trim(substr(text, instr(text, ':') + 1)) when 'true' then 1 else 0 end end) as semicolon_required
  from entity_lines
  where entity_id > 0
  group by entity_id
)
insert into browser_html_named_entity(entity_id, name, code_point_1, code_point_2, semicolon_required)
select entity_id, name, code_point_1, coalesce(code_point_2, 0), coalesce(semicolon_required, 0)
from entity_rows
where name is not null and code_point_1 is not null;

create table browser_html_element_fact (
  element_id integer primary key,
  tag_name text not null unique,
  dom_interface text not null,
  has_global_attributes integer not null,
  content_model text not null,
  tag_omission text not null,
  represents text not null
);

insert into browser_html_element_fact(element_id, tag_name, dom_interface, has_global_attributes, content_model, tag_omission, represents)
select cast(json_each.key as integer) + 1,
       json_extract(json_each.value, '$.tag_name'),
       coalesce(json_extract(json_each.value, '$.dom_interface'), ''),
       case json_extract(json_each.value, '$.has_global_attributes') when 1 then 1 else 0 end,
       coalesce(json_extract(json_each.value, '$.content_model'), ''),
       coalesce(json_extract(json_each.value, '$.tag_omission'), ''),
       coalesce(json_extract(json_each.value, '$.represents'), '')
from browser_spec_source
join json_each(cast(browser_spec_source.content as text), '$.elements')
where browser_spec_source.namespace = 'html.elements';

create table browser_css_property_fact (
  property_id integer primary key,
  name text not null unique,
  value_grammar text not null,
  initial_value text not null,
  inherited text not null,
  computed_value text not null,
  source_file text not null
);

insert into browser_css_property_fact(property_id, name, value_grammar, initial_value, inherited, computed_value, source_file)
select cast(json_each.key as integer) + 1,
       json_extract(json_each.value, '$.name'),
       coalesce(json_extract(json_each.value, '$.value'), ''),
       coalesce(json_extract(json_each.value, '$.initial'), ''),
       coalesce(json_extract(json_each.value, '$.inherited'), ''),
       coalesce(json_extract(json_each.value, '$.computed_value'), ''),
       coalesce(json_extract(json_each.value, '$.source_file'), '')
from browser_spec_source
join json_each(cast(browser_spec_source.content as text), '$.properties')
where browser_spec_source.namespace = 'css.properties';

create table browser_css_selector_fact (
  selector_fact_id integer primary key,
  selector_kind text not null,
  name text not null,
  arguments text not null,
  description text not null,
  unique (selector_kind, name)
);

insert into browser_css_selector_fact(selector_fact_id, selector_kind, name, arguments, description)
select cast(json_each.key as integer) + 1,
       'pseudo_class',
       json_extract(json_each.value, '$.name'),
       coalesce(json_extract(json_each.value, '$.arguments'), ''),
       coalesce(json_extract(json_each.value, '$.description'), '')
from browser_spec_source
join json_each(cast(browser_spec_source.content as text), '$.pseudo_classes')
where browser_spec_source.namespace = 'css.selectors'
union all
select 1000 + cast(json_each.key as integer) + 1,
       'pseudo_element',
       json_extract(json_each.value, '$.name'),
       coalesce(json_extract(json_each.value, '$.arguments'), ''),
       coalesce(json_extract(json_each.value, '$.description'), '')
from browser_spec_source
join json_each(cast(browser_spec_source.content as text), '$.pseudo_elements')
where browser_spec_source.namespace = 'css.selectors';

create table browser_fetch_field_fact (
  field_id integer primary key,
  object_kind text not null,
  name text not null,
  field_type text not null,
  description text not null,
  unique (object_kind, name)
);

insert into browser_fetch_field_fact(field_id, object_kind, name, field_type, description)
select cast(json_each.key as integer) + 1,
       'request_init',
       json_extract(json_each.value, '$.name'),
       coalesce(json_extract(json_each.value, '$.type'), ''),
       coalesce(json_extract(json_each.value, '$.description'), '')
from browser_spec_source
join json_each(cast(browser_spec_source.content as text), '$.request_init')
where browser_spec_source.namespace = 'fetch'
union all
select 1000 + cast(json_each.key as integer) + 1,
       'response_property',
       json_extract(json_each.value, '$.name'),
       coalesce(json_extract(json_each.value, '$.type'), ''),
       coalesce(json_extract(json_each.value, '$.description'), '')
from browser_spec_source
join json_each(cast(browser_spec_source.content as text), '$.response_properties')
where browser_spec_source.namespace = 'fetch';

create table browser_ecmascript_builtin_fact (
  builtin_id integer primary key,
  name text not null unique,
  constructor_signature text not null
);

insert into browser_ecmascript_builtin_fact(builtin_id, name, constructor_signature)
select cast(json_each.key as integer) + 1,
       json_extract(json_each.value, '$.name'),
       coalesce(json_extract(json_each.value, '$.constructor_signature'), '')
from browser_spec_source
join json_each(cast(browser_spec_source.content as text), '$.built_in_objects')
where browser_spec_source.namespace = 'ecmascript';

create table browser_url_parser_state_fact (
  state_id integer primary key,
  name text not null unique
);

insert into browser_url_parser_state_fact(state_id, name)
select cast(json_each.key as integer) + 1,
       json_each.value
from browser_spec_source
join json_each(cast(browser_spec_source.content as text), '$.url_parser_states')
where browser_spec_source.namespace = 'url';

create table browser_url_property_fact (
  property_id integer primary key,
  name text not null unique,
  property_type text not null,
  description text not null
);

insert into browser_url_property_fact(property_id, name, property_type, description)
select cast(json_each.key as integer) + 1,
       json_extract(json_each.value, '$.name'),
       coalesce(json_extract(json_each.value, '$.type'), ''),
       coalesce(json_extract(json_each.value, '$.description'), '')
from browser_spec_source
join json_each(cast(browser_spec_source.content as text), '$.url_properties')
where browser_spec_source.namespace = 'url';

create table browser_encoding_fact (
  encoding_id integer primary key,
  name text not null unique,
  encoding_type text not null,
  endianness text not null
);

create table browser_encoding_label_fact (
  encoding_id integer not null references browser_encoding_fact(encoding_id),
  label text not null unique,
  primary key (encoding_id, label)
);

insert into browser_encoding_fact(encoding_id, name, encoding_type, endianness)
select cast(json_each.key as integer) + 1,
       json_extract(json_each.value, '$.name'),
       coalesce(json_extract(json_each.value, '$.type'), ''),
       coalesce(json_extract(json_each.value, '$.endianness'), '')
from browser_spec_source
join json_each(cast(browser_spec_source.content as text), '$.encodings')
where browser_spec_source.namespace = 'encoding';

insert into browser_encoding_label_fact(encoding_id, label)
select cast(encoding_entry.key as integer) + 1,
       label_entry.value
from browser_spec_source
join json_each(cast(browser_spec_source.content as text), '$.encodings') encoding_entry
join json_each(encoding_entry.value, '$.labels') label_entry
where browser_spec_source.namespace = 'encoding';

create table browser_dom_interface_fact (
  interface_id integer primary key,
  name text not null unique,
  parent text not null
);

create table browser_dom_attribute_fact (
  interface_id integer not null references browser_dom_interface_fact(interface_id),
  attribute_id integer not null,
  name text not null,
  attribute_type text not null,
  readonly_flag integer not null,
  primary key (interface_id, attribute_id),
  unique (interface_id, name)
);

create table browser_dom_method_fact (
  interface_id integer not null references browser_dom_interface_fact(interface_id),
  method_id integer not null,
  name text not null,
  return_type text not null,
  parameter_count integer not null,
  primary key (interface_id, method_id),
  unique (interface_id, name, method_id)
);

insert into browser_dom_interface_fact(interface_id, name, parent)
select cast(json_each.key as integer) + 1,
       json_extract(json_each.value, '$.name'),
       coalesce(json_extract(json_each.value, '$.parent'), '')
from browser_spec_source
join json_each(cast(browser_spec_source.content as text), '$.interfaces')
where browser_spec_source.namespace = 'dom';

insert or ignore into browser_dom_attribute_fact(interface_id, attribute_id, name, attribute_type, readonly_flag)
select cast(interface_entry.key as integer) + 1,
       cast(attribute_entry.key as integer) + 1,
       json_extract(attribute_entry.value, '$.name'),
       coalesce(json_extract(attribute_entry.value, '$.type'), ''),
       case json_extract(attribute_entry.value, '$.readonly') when 1 then 1 else 0 end
from browser_spec_source
join json_each(cast(browser_spec_source.content as text), '$.interfaces') interface_entry
join json_each(interface_entry.value, '$.attributes') attribute_entry
where browser_spec_source.namespace = 'dom';

insert or ignore into browser_dom_method_fact(interface_id, method_id, name, return_type, parameter_count)
select cast(interface_entry.key as integer) + 1,
       cast(method_entry.key as integer) + 1,
       json_extract(method_entry.value, '$.name'),
       coalesce(json_extract(method_entry.value, '$.return_type'), ''),
       coalesce(json_array_length(json_extract(method_entry.value, '$.parameters')), 0)
from browser_spec_source
join json_each(cast(browser_spec_source.content as text), '$.interfaces') interface_entry
join json_each(interface_entry.value, '$.methods') method_entry
where browser_spec_source.namespace = 'dom';

-- Edgerun standards fact import. These facts are mined from /home/ken/edgerun
-- standards TOML/corpus files and utility codec tables. The current TOML parser
-- is useful for scalar tables but does not preserve repeated [[table]] arrays as
-- distinct rows, so this first import records normalized facts directly.
create table edgerun_standards_source (
  source_id integer primary key,
  namespace text not null unique,
  path text not null unique,
  format text not null,
  byte_len integer not null,
  content blob not null
);

insert into edgerun_standards_source(source_id, namespace, path, format, byte_len, content) values
  (1, 'standards.protocol.udp', '/home/ken/edgerun/standards/protocols/udp.toml', 'toml', length(readfile('/home/ken/edgerun/standards/protocols/udp.toml')), readfile('/home/ken/edgerun/standards/protocols/udp.toml')),
  (2, 'standards.protocol.tftp', '/home/ken/edgerun/standards/protocols/tftp.toml', 'toml', length(readfile('/home/ken/edgerun/standards/protocols/tftp.toml')), readfile('/home/ken/edgerun/standards/protocols/tftp.toml')),
  (3, 'standards.protocol.hpack', '/home/ken/edgerun/standards/protocols/hpack.toml', 'toml', length(readfile('/home/ken/edgerun/standards/protocols/hpack.toml')), readfile('/home/ken/edgerun/standards/protocols/hpack.toml')),
  (4, 'standards.protocol.quic', '/home/ken/edgerun/standards/protocols/quic.toml', 'toml', length(readfile('/home/ken/edgerun/standards/protocols/quic.toml')), readfile('/home/ken/edgerun/standards/protocols/quic.toml')),
  (5, 'standards.definition.udp', '/home/ken/edgerun/standards/definitions/udp.toml', 'toml', length(readfile('/home/ken/edgerun/standards/definitions/udp.toml')), readfile('/home/ken/edgerun/standards/definitions/udp.toml')),
  (6, 'standards.definition.tftp', '/home/ken/edgerun/standards/definitions/tftp.toml', 'toml', length(readfile('/home/ken/edgerun/standards/definitions/tftp.toml')), readfile('/home/ken/edgerun/standards/definitions/tftp.toml')),
  (7, 'standards.clause.udp', '/home/ken/edgerun/standards/clauses/udp.toml', 'toml', length(readfile('/home/ken/edgerun/standards/clauses/udp.toml')), readfile('/home/ken/edgerun/standards/clauses/udp.toml')),
  (8, 'standards.clause.tftp', '/home/ken/edgerun/standards/clauses/tftp.toml', 'toml', length(readfile('/home/ken/edgerun/standards/clauses/tftp.toml')), readfile('/home/ken/edgerun/standards/clauses/tftp.toml')),
  (9, 'standards.program.tftp', '/home/ken/edgerun/standards/programs/tftp.toml', 'toml', length(readfile('/home/ken/edgerun/standards/programs/tftp.toml')), readfile('/home/ken/edgerun/standards/programs/tftp.toml')),
  (10, 'standards.corpus.tftp.cases', '/home/ken/edgerun/standards/corpus/tftp/cases.toml', 'toml', length(readfile('/home/ken/edgerun/standards/corpus/tftp/cases.toml')), readfile('/home/ken/edgerun/standards/corpus/tftp/cases.toml')),
  (11, 'hpack.fixture.nghttp2.basic', '/home/ken/edgerun/tests/fixtures/hpack/interop/nghttp2/basic.json', 'json', length(readfile('/home/ken/edgerun/tests/fixtures/hpack/interop/nghttp2/basic.json')), readfile('/home/ken/edgerun/tests/fixtures/hpack/interop/nghttp2/basic.json'));

insert or ignore into edgerun_standards_source(namespace, path, format, byte_len, content)
select 'standards.local.' || replace(replace(substr(name, length('/home/ken/edgerun/standards/') + 1), '/', '.'), '.', '_'),
       name,
       case
         when name like '%.toml' then 'toml'
         when name like '%.hex' then 'hex'
         when name like '%.json' then 'json'
         when name like '%.md' then 'markdown'
         when name like '%.wit' then 'wit'
         else 'text'
       end,
       length(data),
       data
from fsdir('/home/ken/edgerun/standards')
where data is not null
  and length(data) < 2000000
  and (
    name like '%.toml' or name like '%.hex' or name like '%.json'
    or name like '%.md' or name like '%.wit'
  );

insert or ignore into edgerun_standards_source(namespace, path, format, byte_len, content)
select 'hpack.fixture.' || replace(replace(substr(name, length('/home/ken/edgerun/tests/fixtures/hpack/') + 1), '/', '.'), '.', '_'),
       name,
       'json',
       length(data),
       data
from fsdir('/home/ken/edgerun/tests/fixtures/hpack')
where data is not null
  and name like '%.json'
  and length(data) < 2000000;

create table edgerun_protocol_fact (
  protocol_id integer primary key,
  id text not null unique,
  name text not null,
  layer text not null,
  summary text not null
);

insert into edgerun_protocol_fact(protocol_id, id, name, layer, summary) values
  (1, 'udp', 'User Datagram Protocol', 'transport', 'Connectionless transport datagram format over IP.'), (2, 'tftp', 'Trivial File Transfer Protocol', 'application', 'Simple lock-step file transfer over UDP.'), (3, 'hpack', 'HPACK', 'presentation', 'Header compression format for HTTP/2.'), (4, 'quic', 'QUIC', 'transport', 'UDP-based multiplexed secure transport.');

insert or ignore into edgerun_protocol_fact(protocol_id, id, name, layer, summary) values
  (5, 'ethernet', 'Ethernet', 'link', 'Link-layer Ethernet frame transport.'), (6, 'arp', 'Address Resolution Protocol', 'link', 'IPv4 address resolution over link-layer networks.'), (7, 'ipv4', 'Internet Protocol Version 4', 'network', 'IPv4 packet format and routing semantics.'), (8, 'ipv6', 'Internet Protocol Version 6', 'network', 'IPv6 packet format and routing semantics.'), (9, 'icmpv4', 'Internet Control Message Protocol for IPv4', 'network', 'ICMP control messages for IPv4.'), (10, 'icmpv6', 'Internet Control Message Protocol for IPv6', 'network', 'ICMP control messages for IPv6.'), (11, 'tcp', 'Transmission Control Protocol', 'transport', 'Reliable ordered byte stream over IP.'), (12, 'dns', 'Domain Name System', 'application', 'Domain name query and resource record protocol.'), (13, 'dhcpv4', 'Dynamic Host Configuration Protocol for IPv4', 'application', 'IPv4 host configuration over UDP.'), (14, 'dhcpv6', 'Dynamic Host Configuration Protocol for IPv6', 'application', 'IPv6 host configuration over UDP.'), (15, 'http', 'HTTP', 'application', 'Application semantics and message mappings for HTTP/1.1, HTTP/2, and HTTP/3.'), (16, 'nfc', 'Near Field Communication', 'link', 'Near-field radio communication protocols.'), (17, 'qpack', 'QPACK', 'presentation', 'Header compression format for HTTP/3.'), (18, 'tls', 'Transport Layer Security', 'security', 'Authenticated encrypted transport security protocol.');

create table edgerun_protocol_dependency_fact (
  protocol_id integer not null references edgerun_protocol_fact(protocol_id),
  dependency text not null,
  edge_kind text not null,
  primary key (protocol_id, dependency, edge_kind)
);

insert into edgerun_protocol_dependency_fact(protocol_id, dependency, edge_kind) values
  (1, 'IPv4', 'runs_over'), (1, 'IPv6', 'runs_over'), (2, 'UDP', 'runs_over'), (3, 'HTTP/2', 'runs_over'), (4, 'UDP', 'runs_over'), (4, 'TLS 1.3', 'depends_on');

insert or ignore into edgerun_protocol_dependency_fact(protocol_id, dependency, edge_kind) values
  (6, 'Ethernet', 'runs_over'), (7, 'Ethernet', 'runs_over'), (8, 'Ethernet', 'runs_over'), (9, 'IPv4', 'runs_over'), (10, 'IPv6', 'runs_over'), (11, 'IPv4', 'runs_over'), (11, 'IPv6', 'runs_over'), (12, 'UDP', 'runs_over'), (12, 'TCP', 'runs_over'), (12, 'TLS', 'runs_over'), (12, 'HTTPS', 'runs_over'), (12, 'QUIC', 'runs_over'), (13, 'UDP', 'runs_over'), (13, 'IPv4', 'runs_over'), (14, 'UDP', 'runs_over'), (14, 'IPv6', 'runs_over'), (15, 'TCP', 'runs_over'), (15, 'TLS', 'runs_over'), (15, 'QUIC', 'runs_over'), (17, 'HTTP/3', 'runs_over'), (17, 'QUIC', 'runs_over'), (18, 'TCP', 'runs_over'), (18, 'QUIC', 'runs_over');

create table edgerun_protocol_standard_fact (
  protocol_id integer not null references edgerun_protocol_fact(protocol_id),
  standard_id text not null,
  title text not null,
  role text not null,
  url text not null,
  primary key (protocol_id, standard_id, role)
);

insert into edgerun_protocol_standard_fact(protocol_id, standard_id, title, role, url) values
  (1, 'RFC768', 'User Datagram Protocol', 'base', 'https://www.rfc-editor.org/rfc/rfc768.html'),
  (1, 'RFC1122', 'Requirements for Internet Hosts - Communication Layers', 'host-requirements', 'https://www.rfc-editor.org/rfc/rfc1122.html'),
  (2, 'RFC1350', 'The TFTP Protocol (Revision 2)', 'base', 'https://www.rfc-editor.org/rfc/rfc1350.html'),
  (3, 'RFC7541', 'HPACK: Header Compression for HTTP/2', 'base', 'https://www.rfc-editor.org/rfc/rfc7541.html'),
  (4, 'RFC9000', 'QUIC: A UDP-Based Multiplexed and Secure Transport', 'transport', 'https://www.rfc-editor.org/rfc/rfc9000.html'),
  (4, 'RFC9001', 'Using TLS to Secure QUIC', 'tls-mapping', 'https://www.rfc-editor.org/rfc/rfc9001.html'),
  (4, 'RFC9002', 'QUIC Loss Detection and Congestion Control', 'recovery', 'https://www.rfc-editor.org/rfc/rfc9002.html'),
  (5, 'IEEE802.3', 'IEEE Ethernet', 'base', ''),
  (6, 'RFC826', 'An Ethernet Address Resolution Protocol', 'base', 'https://www.rfc-editor.org/rfc/rfc826.html'),
  (7, 'RFC791', 'Internet Protocol', 'base', 'https://www.rfc-editor.org/rfc/rfc791.html'),
  (8, 'RFC8200', 'Internet Protocol, Version 6 (IPv6) Specification', 'base', 'https://www.rfc-editor.org/rfc/rfc8200.html'),
  (9, 'RFC792', 'Internet Control Message Protocol', 'base', 'https://www.rfc-editor.org/rfc/rfc792.html'),
  (10, 'RFC4443', 'Internet Control Message Protocol (ICMPv6)', 'base', 'https://www.rfc-editor.org/rfc/rfc4443.html'),
  (11, 'RFC9293', 'Transmission Control Protocol (TCP)', 'base', 'https://www.rfc-editor.org/rfc/rfc9293.html'),
  (12, 'RFC1034', 'Domain Names - Concepts and Facilities', 'concepts', 'https://www.rfc-editor.org/rfc/rfc1034.html'),
  (12, 'RFC1035', 'Domain Names - Implementation and Specification', 'base', 'https://www.rfc-editor.org/rfc/rfc1035.html'),
  (13, 'RFC2131', 'Dynamic Host Configuration Protocol', 'base', 'https://www.rfc-editor.org/rfc/rfc2131.html'),
  (14, 'RFC8415', 'Dynamic Host Configuration Protocol for IPv6', 'base', 'https://www.rfc-editor.org/rfc/rfc8415.html'),
  (15, 'RFC9110', 'HTTP Semantics', 'semantics', 'https://www.rfc-editor.org/rfc/rfc9110.html'),
  (15, 'RFC9112', 'HTTP/1.1', 'http1', 'https://www.rfc-editor.org/rfc/rfc9112.html'),
  (15, 'RFC9113', 'HTTP/2', 'http2', 'https://www.rfc-editor.org/rfc/rfc9113.html'),
  (15, 'RFC9114', 'HTTP/3', 'http3', 'https://www.rfc-editor.org/rfc/rfc9114.html'),
  (16, 'NFC-FORUM', 'NFC Forum Specifications', 'base', ''),
  (17, 'RFC9204', 'QPACK: Field Compression for HTTP/3', 'base', 'https://www.rfc-editor.org/rfc/rfc9204.html'),
  (18, 'RFC8446', 'The Transport Layer Security (TLS) Protocol Version 1.3', 'base', 'https://www.rfc-editor.org/rfc/rfc8446.html');

create table edgerun_protocol_behavior_fact (
  behavior_id integer primary key,
  protocol_id integer not null references edgerun_protocol_fact(protocol_id),
  behavior_name text not null,
  behavior_kind text not null,
  status text not null,
  unique (protocol_id, behavior_name)
);

insert into edgerun_protocol_behavior_fact(behavior_id, protocol_id, behavior_name, behavior_kind, status) values
  (1, 1, 'udp-header-parse', 'packet-format', 'unknown'), (2, 1, 'udp-checksum', 'checksum', 'unknown'), (3, 2, 'tftp-message-parse', 'message-format', 'unknown'), (4, 3, 'hpack-integer-codec', 'codec', 'unknown'), (5, 3, 'hpack-dynamic-table', 'state-machine', 'unknown'), (6, 4, 'quic-varint', 'codec', 'unknown'), (7, 15, 'http-message-parsing', 'message-format', 'unknown'), (8, 15, 'http-content-coding', 'semantics', 'unknown'), (9, 17, 'qpack-integer-codec', 'codec', 'unknown'), (10, 18, 'tls-record-parse', 'record-format', 'unknown');

create table edgerun_protocol_environment_fact (
  protocol_id integer primary key references edgerun_protocol_fact(protocol_id),
  requires_network_io integer not null,
  requires_packet_io integer not null,
  requires_stream_io integer not null,
  requires_crypto integer not null,
  requires_allocator integer not null,
  no_std_viability text not null
);

insert into edgerun_protocol_environment_fact(protocol_id, requires_network_io, requires_packet_io, requires_stream_io, requires_crypto, requires_allocator, no_std_viability) values
  (1, 1, 1, 0, 0, 0, 'plausible'), (2, 1, 0, 0, 0, 0, 'plausible'), (3, 0, 0, 0, 0, 1, 'plausible-with-alloc'), (4, 1, 1, 1, 1, 1, 'complex'), (5, 1, 1, 0, 0, 0, 'plausible'), (6, 1, 1, 0, 0, 0, 'plausible'), (7, 1, 1, 0, 0, 0, 'plausible'), (8, 1, 1, 0, 0, 0, 'plausible'), (9, 1, 1, 0, 0, 0, 'plausible'), (10, 1, 1, 0, 0, 0, 'plausible'), (11, 1, 1, 1, 0, 1, 'plausible-with-alloc'), (12, 1, 1, 1, 0, 1, 'plausible-with-alloc'), (13, 1, 1, 0, 0, 1, 'plausible-with-alloc'), (14, 1, 1, 0, 0, 1, 'plausible-with-alloc'), (15, 1, 0, 1, 0, 1, 'plausible-with-alloc'), (16, 1, 1, 0, 0, 0, 'plausible'), (17, 0, 0, 0, 0, 1, 'plausible-with-alloc'), (18, 1, 0, 1, 1, 1, 'complex');

create table edgerun_definition_fact (
  definition_id integer primary key,
  id text not null unique,
  kind text not null,
  standard text not null,
  section text not null
);

create table edgerun_definition_field_fact (
  definition_id integer not null references edgerun_definition_fact(definition_id),
  field_order integer not null,
  name text not null,
  field_type text not null,
  length_expr text not null default '',
  constraint_expr text not null default '',
  primary key (definition_id, field_order)
);

create table edgerun_definition_variant_fact (
  definition_id integer not null references edgerun_definition_fact(definition_id),
  variant_name text not null,
  tag_field text not null,
  tag_value integer not null,
  primary key (definition_id, variant_name)
);

insert into edgerun_definition_fact(definition_id, id, kind, standard, section) values
  (1, 'udp-datagram', 'frame', 'RFC768', 'Format'), (2, 'tftp-message', 'sum-frame', 'RFC1350', '5');

insert into edgerun_definition_field_fact(definition_id, field_order, name, field_type, length_expr, constraint_expr) values
  (1, 1, 'source_port', 'u16be', '', ''), (1, 2, 'destination_port', 'u16be', '', ''), (1, 3, 'length', 'u16be', '', 'length >= 8'), (1, 4, 'checksum', 'u16be', '', ''), (1, 5, 'payload', 'bytes', 'length - 8', ''), (2, 1, 'opcode', 'u16be', '', '');

insert into edgerun_definition_variant_fact(definition_id, variant_name, tag_field, tag_value) values
  (2, 'rrq', 'opcode', 1), (2, 'wrq', 'opcode', 2), (2, 'data', 'opcode', 3), (2, 'ack', 'opcode', 4), (2, 'error', 'opcode', 5);

create table edgerun_clause_fact (
  clause_id integer primary key,
  id text not null unique,
  standard text not null,
  section text not null,
  keyword text not null,
  subject text not null,
  predicate_expr text not null,
  violation_code text not null,
  violation_message text not null
);

insert into edgerun_clause_fact(clause_id, id, standard, section, keyword, subject, predicate_expr, violation_code, violation_message) values
  (1, 'udp-rfc768-length-0001', 'RFC768', 'Format', 'MUST', 'udp-datagram', 'length >= 8 && length == payload_len + 8', 'UDP_LENGTH_INVALID', 'UDP length does not match header plus payload length.'), (2, 'tftp-rfc1350-opcode-0001', 'RFC1350', '5', 'MUST', 'tftp-message', 'byte_len >= 2 && opcode in [1, 2, 3, 4, 5, 6]', 'TFTP_OPCODE_INVALID', 'TFTP opcode is missing or unknown.'), (3, 'tftp-rfc1350-ack-length-0001', 'RFC1350', '5', 'MUST', 'tftp-message', 'opcode != 4 || byte_len == 4', 'TFTP_ACK_LENGTH_INVALID', 'TFTP ACK packets must be exactly four octets.'), (4, 'tftp-rfc1350-data-length-0001', 'RFC1350', '5', 'MUST', 'tftp-message', 'opcode != 3 || byte_len >= 4', 'TFTP_DATA_LENGTH_INVALID', 'TFTP DATA packets must include a two-octet block number.'), (5, 'tftp-message-definition', 'RFC1350', '5', 'MUST', 'tftp-message', 'byte_len >= 2', 'TFTP_MESSAGE_TOO_SHORT', 'TFTP messages must include a two-octet opcode.');

create table engine_field_type_fact (
  field_type text primary key,
  byte_len integer not null,
  endian text not null
);

insert into engine_field_type_fact(field_type, byte_len, endian) values
  ('u16be', 2, 'big'), ('bytes', 0, 'variable');

create table engine_corpus_root_fact (
  corpus_name text primary key,
  root_definition_id text not null
);

insert into engine_corpus_root_fact(corpus_name, root_definition_id) values
  ('tftp', 'tftp-message'), ('udp-tftp', 'udp-datagram');

create table engine_definition_composition_fact (
  parent_definition_id text not null,
  child_definition_id text not null,
  parent_field_name text not null,
  primary key (parent_definition_id, child_definition_id, parent_field_name)
);

insert into engine_definition_composition_fact(parent_definition_id, child_definition_id, parent_field_name) values
  ('udp-datagram', 'tftp-message', 'payload');

create table engine_case_value_derivation_fact (
  definition_id text not null,
  value_name text not null,
  source_value_name text not null,
  integer_add integer not null,
  primary key (definition_id, value_name)
);

insert into engine_case_value_derivation_fact(definition_id, value_name, source_value_name, integer_add) values
  ('*', 'byte_len', 'corpus_byte_len', 0), ('udp-datagram', 'payload_len', 'byte_len', -8);

create view engine_definition_field_layout_fact as
select definition.id as definition_id,
       field.name as field_name,
       field.field_type,
       coalesce((select sum(prev_type.byte_len)
                 from edgerun_definition_field_fact prev_field
                 join engine_field_type_fact prev_type on prev_type.field_type = prev_field.field_type
                 where prev_field.definition_id = field.definition_id
                   and prev_field.field_order < field.field_order), 0) as byte_offset,
       field_type.byte_len,
       field_type.endian
from edgerun_definition_field_fact field
join edgerun_definition_fact definition using (definition_id)
join engine_field_type_fact field_type on field_type.field_type = field.field_type;

create view engine_corpus_definition_binding_fact as
select corpus_name,
       root_definition_id as definition_id,
       0 as base_byte_offset
from engine_corpus_root_fact
union all
select root.corpus_name,
       composition.child_definition_id,
       parent_layout.byte_offset
from engine_corpus_root_fact root
join engine_definition_composition_fact composition
  on composition.parent_definition_id = root.root_definition_id
join engine_definition_field_layout_fact parent_layout
  on parent_layout.definition_id = composition.parent_definition_id
 and parent_layout.field_name = composition.parent_field_name;

create table engine_predicate_operator_fact (
  operator_name text primary key,
  operator_kind text not null,
  operand_kind text not null
);

insert into engine_predicate_operator_fact(operator_name, operator_kind, operand_kind) values
  ('>=', 'compare', 'integer'),
  ('==', 'compare', 'integer'),
  ('!=', 'compare', 'integer'),
  ('in', 'membership', 'integer_set');

create table engine_clause_predicate_atom_fact (
  clause_id integer not null references edgerun_clause_fact(clause_id),
  group_index integer not null,
  atom_index integer not null,
  lhs_name text not null,
  operator_name text not null references engine_predicate_operator_fact(operator_name),
  rhs_integer integer,
  rhs_value_name text not null,
  rhs_integer_add integer not null,
  primary key (clause_id, group_index, atom_index)
);

insert into engine_clause_predicate_atom_fact(clause_id, group_index, atom_index, lhs_name, operator_name, rhs_integer, rhs_value_name, rhs_integer_add) values
  (1, 1, 1, 'length', '>=', 8, '', 0),
  (1, 1, 2, 'length', '==', null, 'payload_len', 8),
  (2, 1, 1, 'byte_len', '>=', 2, '', 0),
  (2, 1, 2, 'opcode', 'in', null, '', 0),
  (3, 1, 1, 'opcode', '!=', 4, '', 0),
  (3, 2, 1, 'byte_len', '==', 4, '', 0),
  (4, 1, 1, 'opcode', '!=', 3, '', 0),
  (4, 2, 1, 'byte_len', '>=', 4, '', 0),
  (5, 1, 1, 'byte_len', '>=', 2, '', 0);

create table engine_clause_predicate_set_member_fact (
  clause_id integer not null,
  group_index integer not null,
  atom_index integer not null,
  member_integer integer not null,
  primary key (clause_id, group_index, atom_index, member_integer),
  foreign key (clause_id, group_index, atom_index) references engine_clause_predicate_atom_fact(clause_id, group_index, atom_index)
);

insert into engine_clause_predicate_set_member_fact(clause_id, group_index, atom_index, member_integer) values
  (2, 1, 2, 1),
  (2, 1, 2, 2),
  (2, 1, 2, 3),
  (2, 1, 2, 4),
  (2, 1, 2, 5),
  (2, 1, 2, 6);

create view engine_clause_predicate_parse_gap as
select clause.id as clause_name,
       clause.clause_id,
       0 as group_index,
       0 as atom_index,
       clause.predicate_expr as atom_text,
       'missing_predicate_atom_fact' as gap_kind
from edgerun_clause_fact clause
left join engine_clause_predicate_atom_fact atom using (clause_id)
where atom.clause_id is null;

create table engine_category_fact (
  category_name text primary key,
  description text not null
);

insert into engine_category_fact(category_name, description) values
  ('driver', 'Code or object that drives a device.'),
  ('device', 'Hardware or virtual device entity.'),
  ('clock', 'Clock source or clock domain.'),
  ('frequency', 'Rate measured as cycles per time.'),
  ('register', 'Addressable register entity.'),
  ('field', 'Sub-register or protocol field entity.'),
  ('offset', 'Byte or bit displacement.'),
  ('width', 'Width in bits or bytes.'),
  ('encoder', 'Entity that maps values to bytes or symbols.'),
  ('media_format', 'Concrete media container or canonical media byte format.'),
  ('codec', 'Codec identifier or payload coding used by a media format.'),
  ('protocol', 'Message or transport protocol.'),
  ('message', 'Structured protocol message.'),
  ('unit', 'Measurement unit.'),
  ('constant', 'Imported immutable symbolic value.'),
  ('relation', 'Typed relation between entities or values.'),
  ('decision', 'A choice point that can be evaluated by explicit tradeoff facts.'),
  ('option', 'A candidate implementation or workflow choice for a decision.'),
  ('metric', 'A measured or estimated cost, benefit, risk, or constraint used in a tradeoff.'),
  ('tradeoff', 'An assessment that relates an option to a metric with a scored effect.'),
  ('standard', 'External or internal specification source.'),
  ('clause', 'Executable requirement or validation predicate.');

create table engine_category_relation_fact (
  child_category text not null references engine_category_fact(category_name),
  relation_name text not null,
  parent_category text not null references engine_category_fact(category_name),
  primary key (child_category, relation_name, parent_category)
);

insert into engine_category_relation_fact(child_category, relation_name, parent_category) values
  ('frequency', 'measured_in', 'unit'),
  ('offset', 'measured_in', 'unit'),
  ('width', 'measured_in', 'unit'),
  ('register', 'has_field', 'field'),
  ('device', 'has_register', 'register'),
  ('device', 'has_clock', 'clock'),
  ('clock', 'has_rate', 'frequency'),
  ('protocol', 'has_message', 'message'),
  ('message', 'has_field', 'field'),
  ('media_format', 'has_field', 'field'),
  ('media_format', 'supports_codec', 'codec'),
  ('encoder', 'emits', 'message'),
  ('clause', 'constrains', 'message'),
  ('decision', 'has_option', 'option'),
  ('option', 'has_tradeoff', 'tradeoff'),
  ('tradeoff', 'uses_metric', 'metric'),
  ('clause', 'defined_by', 'standard');

create table engine_unit_fact (
  unit_name text primary key,
  category_name text not null references engine_category_fact(category_name),
  base_unit_name text not null,
  scale_to_base integer not null
);

insert into engine_unit_fact(unit_name, category_name, base_unit_name, scale_to_base) values
  ('hz', 'frequency', 'hz', 1),
  ('khz', 'frequency', 'hz', 1000),
  ('mhz', 'frequency', 'hz', 1000000),
  ('bit', 'width', 'bit', 1),
  ('byte', 'width', 'bit', 8),
  ('byte_offset', 'offset', 'byte_offset', 1),
  ('bit_offset', 'offset', 'bit_offset', 1);

create table engine_relation_kind_fact (
  relation_name text primary key,
  relation_kind text not null,
  cardinality text not null
);

insert into engine_relation_kind_fact(relation_name, relation_kind, cardinality) values
  ('clock_rate', 'measurement', 'single'),
  ('register_offset', 'layout', 'single'),
  ('field_offset', 'layout', 'single'),
  ('field_width', 'layout', 'single'),
  ('measured_in', 'measurement', 'many'),
  ('has_field', 'structure', 'many'),
  ('has_message', 'structure', 'many'),
  ('has_clock', 'structure', 'many'),
  ('has_register', 'structure', 'many'),
  ('has_command', 'structure', 'many'),
  ('has_reply_code', 'structure', 'many'),
  ('has_rate', 'measurement', 'single'),
  ('has_constant', 'structure', 'many'),
  ('constant_value', 'measurement', 'single'),
  ('emits_event', 'event', 'many'),
  ('supports_codec', 'structure', 'many'),
  ('has_signature', 'identity', 'many'),
  ('constrains', 'constraint', 'many'),
  ('defined_by', 'provenance', 'many'),
  ('emits', 'transform', 'many'),
  ('encodes', 'transform', 'many'),
  ('decodes', 'transform', 'many'),
  ('drives', 'authority', 'many'),
  ('depends_on', 'dependency', 'many'),
  ('compatible_with', 'compatibility', 'many'),
  ('has_option', 'decision', 'many'),
  ('has_tradeoff', 'decision', 'many'),
  ('uses_metric', 'decision', 'single'),
  ('tradeoff_score', 'measurement', 'single'),
  ('tradeoff_weight', 'measurement', 'single');

create table engine_tradeoff_decision_fact (
  decision_id text primary key,
  decision_name text not null,
  decision_goal text not null,
  source_name text not null
);

create table engine_tradeoff_option_fact (
  option_id text primary key,
  decision_id text not null references engine_tradeoff_decision_fact(decision_id),
  option_name text not null,
  option_summary text not null,
  option_status text not null
);

create table engine_tradeoff_metric_fact (
  metric_id text primary key,
  metric_name text not null,
  metric_kind text not null,
  polarity integer not null,
  description text not null
);

create table engine_tradeoff_assessment_fact (
  assessment_id text primary key,
  option_id text not null references engine_tradeoff_option_fact(option_id),
  metric_id text not null references engine_tradeoff_metric_fact(metric_id),
  score integer not null,
  weight integer not null,
  evidence text not null
);

insert into engine_tradeoff_decision_fact(decision_id, decision_name, decision_goal, source_name) values
  ('asm_source_object_conversion', 'Convert tracked ASM test source to source objects', 'Delete textual source only when equivalent source-object and fact-readiness data exist.', 'catalog.sql'),
  ('repo_asm_operator_loop', 'Materialize repo ASM operator-loop relations', 'Reduce repeated work needed to choose the next source-to-fact lowering step.', 'catalog.sql'),
  ('repo_asm_next_action_workflow', 'Use a single next-action queue for source deletion work', 'Reduce per-round operator work by ranking ready deletion, full unlocks, near-ready files, and broad impact gaps in one relation.', 'catalog.sql'),
  ('exact_encoding_increment', 'Add exact fixed encodings one finite fact at a time', 'Increase materializable ASM coverage without growing a competing assembler.', 'catalog.sql'),
  ('source_deletion_acceleration', 'Choose fastest safe source deletion accelerator', 'Maximize deletable source bytes without losing unparsed meaning or growing fallback compiler behavior.', 'catalog.sql');

insert into engine_tradeoff_option_fact(option_id, decision_id, option_name, option_summary, option_status) values
  ('asm_source_object_conversion.source_object', 'asm_source_object_conversion', 'Use committed source objects', 'Keep .asm.erobj as authority and delete matching tracked text once deletion-readiness is complete.', 'selected'),
  ('asm_source_object_conversion.keep_text', 'asm_source_object_conversion', 'Keep tracked text source', 'Preserve existing .asm files as source authority while building facts beside them.', 'rejected'),
  ('repo_asm_operator_loop.materialize_indexed', 'repo_asm_operator_loop', 'Materialize indexed operation status', 'Build indexed operation, match, and status tables during catalog load for fast next-gap queries.', 'selected'),
  ('repo_asm_operator_loop.nested_views', 'repo_asm_operator_loop', 'Recompute nested views', 'Leave all operator-loop queries as derived views over file import and source parsing.', 'rejected'),
  ('repo_asm_next_action_workflow.single_queue', 'repo_asm_next_action_workflow', 'Query one ranked action table', 'Read one deterministic action queue that carries the next action, sample line, impacted bytes, unlock count, and rationale.', 'selected'),
  ('repo_asm_next_action_workflow.manual_queries', 'repo_asm_next_action_workflow', 'Run manual planner queries', 'Manually query deletion states, near-ready files, gap impact, and examples every operator round.', 'rejected'),
  ('exact_encoding_increment.exact_facts', 'exact_encoding_increment', 'Add exact encoding facts', 'Add checked exact instruction encodings that remove high-count known gaps.', 'selected'),
  ('exact_encoding_increment.generic_encoder', 'exact_encoding_increment', 'Add a generic encoder', 'Grow generalized textual assembler logic before finite fact coverage proves the need.', 'rejected'),
  ('source_deletion_acceleration.expand_parse_coverage', 'source_deletion_acceleration', 'Expand parse coverage first', 'Treat unparsed significant lines as fatal blockers and import top-level labels/data/test entry forms before more encodings.', 'selected'),
  ('source_deletion_acceleration.more_exact_encodings', 'source_deletion_acceleration', 'Add more exact encodings first', 'Continue adding fixed instruction facts while many files still have unparsed significant lines.', 'rejected'),
  ('source_deletion_acceleration.delete_near_ready_only', 'source_deletion_acceleration', 'Delete near-ready files only', 'Only wrap/delete files already close to fact-backed and ignore broad parser coverage.', 'rejected');

insert into engine_tradeoff_metric_fact(metric_id, metric_name, metric_kind, polarity, description) values
  ('round_query_cost', 'Per-round query cost', 'cost', 1, 'Desirability score for time spent recomputing the next work queue after catalog load; higher means lower cost.'),
  ('catalog_load_cost', 'Catalog load cost', 'cost', 1, 'Desirability score for upfront time to import and materialize the relation database; higher means lower cost.'),
  ('source_deletion_progress', 'Source deletion progress', 'benefit', 1, 'Amount of tracked textual source that can be replaced by facts and source objects.'),
  ('canonical_alignment', 'Canonical model alignment', 'benefit', 1, 'How strongly the option moves authority from source text to finite facts and relations.'),
  ('scope_risk', 'Scope risk', 'risk', -1, 'Risk of expanding into a parallel assembler, hidden workflow, or broad unsupported behavior.');

insert into engine_tradeoff_assessment_fact(assessment_id, option_id, metric_id, score, weight, evidence) values
  ('asm_source_object_conversion.source_object.source_deletion_progress', 'asm_source_object_conversion.source_object', 'source_deletion_progress', 4, 5, 'Converted source objects retain authority; full-line facts now distinguish text deletion from complete fact backing.'),
  ('asm_source_object_conversion.source_object.canonical_alignment', 'asm_source_object_conversion.source_object', 'canonical_alignment', 5, 5, 'Source object is committed authority and catalog facts classify operations.'),
  ('asm_source_object_conversion.source_object.scope_risk', 'asm_source_object_conversion.source_object', 'scope_risk', 1, 4, 'No new parser or fallback source path is added.'),
  ('asm_source_object_conversion.keep_text.source_deletion_progress', 'asm_source_object_conversion.keep_text', 'source_deletion_progress', 0, 5, 'Tracked text remains source authority.'),
  ('asm_source_object_conversion.keep_text.canonical_alignment', 'asm_source_object_conversion.keep_text', 'canonical_alignment', 1, 5, 'Facts remain beside source text instead of replacing it.'),
  ('repo_asm_operator_loop.materialize_indexed.round_query_cost', 'repo_asm_operator_loop.materialize_indexed', 'round_query_cost', 5, 5, 'Next encoding candidates query runs in about 0.04 seconds after load.'),
  ('repo_asm_operator_loop.materialize_indexed.catalog_load_cost', 'repo_asm_operator_loop.materialize_indexed', 'catalog_load_cost', 2, 3, 'Catalog load is about 13 seconds after indexing parsed operations.'),
  ('repo_asm_operator_loop.materialize_indexed.canonical_alignment', 'repo_asm_operator_loop.materialize_indexed', 'canonical_alignment', 4, 5, 'Operator queue reads resident relations instead of re-parsing source views.'),
  ('repo_asm_operator_loop.nested_views.round_query_cost', 'repo_asm_operator_loop.nested_views', 'round_query_cost', 1, 5, 'Repeated next-gap queries took tens of seconds.'),
  ('repo_asm_operator_loop.nested_views.catalog_load_cost', 'repo_asm_operator_loop.nested_views', 'catalog_load_cost', 4, 3, 'Initial catalog load was lower, but each round paid the query cost again.'),
  ('repo_asm_next_action_workflow.single_queue.round_query_cost', 'repo_asm_next_action_workflow.single_queue', 'round_query_cost', 5, 5, 'One relation ranks ready deletion, unlock gaps, near-ready files, and broad impact gaps.'),
  ('repo_asm_next_action_workflow.single_queue.source_deletion_progress', 'repo_asm_next_action_workflow.single_queue', 'source_deletion_progress', 5, 5, 'The queue prioritizes ready deletion and full file unlocks before broad aggregate gap reduction.'),
  ('repo_asm_next_action_workflow.single_queue.canonical_alignment', 'repo_asm_next_action_workflow.single_queue', 'canonical_alignment', 5, 5, 'Workflow state is stored as finite queryable facts instead of operator notes.'),
  ('repo_asm_next_action_workflow.single_queue.scope_risk', 'repo_asm_next_action_workflow.single_queue', 'scope_risk', 1, 5, 'Only ranks existing facts; it adds no parser, fallback, or broad encoder behavior.'),
  ('repo_asm_next_action_workflow.manual_queries.round_query_cost', 'repo_asm_next_action_workflow.manual_queries', 'round_query_cost', 1, 5, 'Each round repeats separate deletion, impact, near-ready, and example lookups.'),
  ('repo_asm_next_action_workflow.manual_queries.source_deletion_progress', 'repo_asm_next_action_workflow.manual_queries', 'source_deletion_progress', 3, 5, 'Manual querying can find the same work but wastes loop time and misses easy unlocks.'),
  ('repo_asm_next_action_workflow.manual_queries.canonical_alignment', 'repo_asm_next_action_workflow.manual_queries', 'canonical_alignment', 2, 5, 'Decision state lives in transient operator context instead of catalog relations.'),
  ('repo_asm_next_action_workflow.manual_queries.scope_risk', 'repo_asm_next_action_workflow.manual_queries', 'scope_risk', 2, 5, 'Manual loops invite inconsistent ranking but do not add executable behavior.'),
  ('exact_encoding_increment.exact_facts.source_deletion_progress', 'exact_encoding_increment.exact_facts', 'source_deletion_progress', 4, 4, 'dec ecx and dec eax moved 154 inventory operations to fixed encodings.'),
  ('exact_encoding_increment.exact_facts.scope_risk', 'exact_encoding_increment.exact_facts', 'scope_risk', 1, 5, 'Finite exact facts do not grow a textual assembler.'),
  ('exact_encoding_increment.generic_encoder.source_deletion_progress', 'exact_encoding_increment.generic_encoder', 'source_deletion_progress', 3, 4, 'Could cover more syntax quickly, but would move toward broad assembler behavior.'),
  ('exact_encoding_increment.generic_encoder.scope_risk', 'exact_encoding_increment.generic_encoder', 'scope_risk', 5, 5, 'High risk of growing a competing yasm-like path.'),
  ('source_deletion_acceleration.expand_parse_coverage.source_deletion_progress', 'source_deletion_acceleration.expand_parse_coverage', 'source_deletion_progress', 5, 5, 'Full-line ASM import brings unparsed significant lines to zero across repo ASM candidates.'),
  ('source_deletion_acceleration.expand_parse_coverage.canonical_alignment', 'source_deletion_acceleration.expand_parse_coverage', 'canonical_alignment', 5, 5, 'Every non-comment ASM line must enter facts before source text can be deleted safely.'),
  ('source_deletion_acceleration.expand_parse_coverage.scope_risk', 'source_deletion_acceleration.expand_parse_coverage', 'scope_risk', 1, 5, 'Coverage facts fail closed instead of pretending partially parsed files are ready.'),
  ('source_deletion_acceleration.more_exact_encodings.source_deletion_progress', 'source_deletion_acceleration.more_exact_encodings', 'source_deletion_progress', 2, 5, 'Top exact encoding gaps impact many bytes but unlock no files while parse coverage is missing.'),
  ('source_deletion_acceleration.more_exact_encodings.scope_risk', 'source_deletion_acceleration.more_exact_encodings', 'scope_risk', 2, 5, 'Finite encodings are safe, but they do not cover top-level unparsed meaning.'),
  ('source_deletion_acceleration.delete_near_ready_only.source_deletion_progress', 'source_deletion_acceleration.delete_near_ready_only', 'source_deletion_progress', 1, 5, 'Only already converted source-object tests are currently fully fact-backed.'),
  ('source_deletion_acceleration.delete_near_ready_only.canonical_alignment', 'source_deletion_acceleration.delete_near_ready_only', 'canonical_alignment', 2, 5, 'Avoids loss but does not address broad source authority.');

create view engine_tradeoff_option_score as
select option.decision_id,
       option.option_id,
       option.option_name,
       option.option_status,
       sum(metric.polarity * assessment.score * assessment.weight) as weighted_score,
       group_concat(metric.metric_id || '=' || cast(assessment.score as text), ',') as score_evidence
from engine_tradeoff_option_fact option
join engine_tradeoff_assessment_fact assessment using (option_id)
join engine_tradeoff_metric_fact metric using (metric_id)
group by option.decision_id, option.option_id, option.option_name, option.option_status;

create view engine_tradeoff_selected_option as
select *
from (
  select score.*,
         row_number() over (partition by decision_id order by weighted_score desc, option_id) as rank
  from engine_tradeoff_option_score score
)
where rank = 1;

create table tor_control_command_fact (
  command_name text primary key,
  command_kind text not null,
  host_surface_status text not null,
  source_name text not null,
  source_line integer not null
);

insert into tor_control_command_fact(command_name, command_kind, host_surface_status, source_name, source_line) values
  ('SETCONF', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 20), ('RESETCONF', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 37), ('GETCONF', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 47), ('SETEVENTS', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 77), ('AUTHENTICATE', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 95), ('SAVECONF', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 128), ('SIGNAL', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 144), ('MAPADDRESS', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 195), ('GETINFO', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 256), ('EXTENDCIRCUIT', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 900), ('SETCIRCUITPURPOSE', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 922), ('SETROUTERPURPOSE', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 932), ('ATTACHSTREAM', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 944), ('POSTDESCRIPTOR', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 966), ('REDIRECTSTREAM', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 983), ('CLOSESTREAM', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 997), ('CLOSECIRCUIT', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 1009), ('QUIT', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 1024), ('USEFEATURE', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 1028), ('EXTENDED_EVENTS', 'feature', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 1047), ('VERBOSE_NAMES', 'feature', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 1053), ('RESOLVE', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 1059), ('PROTOCOLINFO', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 1073), ('LOADCONF', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 1128), ('TAKEOWNERSHIP', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 1140), ('AUTHCHALLENGE', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 1180), ('DROPGUARDS', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 1228), ('HSFETCH', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 1242), ('ADD_ONION', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 1284), ('DEL_ONION', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 1452), ('HSPOST', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 1473), ('ONION_CLIENT_AUTH_ADD', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 1506), ('ONION_CLIENT_AUTH_REMOVE', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 1546), ('ONION_CLIENT_AUTH_VIEW', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 1565), ('DROPOWNERSHIP', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 1601), ('DROPTIMEOUTS', 'command', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 1617);

create table tor_control_event_fact (
  event_name text primary key,
  event_area text not null,
  host_surface_status text not null,
  source_name text not null,
  source_line integer not null
);

insert into tor_control_event_fact(event_name, event_area, host_surface_status, source_name, source_line) values
  ('CIRC', 'circuit', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 2472), ('STREAM', 'stream', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 2620), ('ORCONN', 'or_connection', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 2742), ('BW', 'bandwidth', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 2811), ('DEBUG', 'log', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 2826), ('INFO', 'log', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 2826), ('NOTICE', 'log', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 2826), ('WARN', 'log', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 2826), ('ERR', 'log', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 2826), ('NEWDESC', 'directory', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 2842), ('ADDRMAP', 'address_mapping', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 2858), ('AUTHDIR_NEWDESCS', 'directory', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 2887), ('DESCCHANGED', 'directory', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 2904), ('STATUS_GENERAL', 'status', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 2914), ('STATUS_CLIENT', 'status', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 2914), ('STATUS_SERVER', 'status', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 2914), ('GUARD', 'guard', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 3244), ('NS', 'directory', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 3277), ('STREAM_BW', 'bandwidth', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 3289), ('CLIENTS_SEEN', 'statistics', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 3309), ('NEWCONSENSUS', 'directory', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 3339), ('BUILDTIMEOUT_SET', 'circuit', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 3352), ('SIGNAL', 'signal', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 3381), ('CONF_CHANGED', 'configuration', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 3399), ('CIRC_MINOR', 'circuit', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 3413), ('TRANSPORT_LAUNCHED', 'transport', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 3437), ('CONN_BW', 'bandwidth', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 3453), ('CIRC_BW', 'bandwidth', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 3481), ('CELL_STATS', 'statistics', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 3527), ('TB_EMPTY', 'bandwidth', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 3584), ('HS_DESC', 'onion_service', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 3621), ('HS_DESC_CONTENT', 'onion_service', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 3676), ('NETWORK_LIVENESS', 'network', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 3702), ('PT_LOG', 'transport', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 3716), ('PT_STATUS', 'transport', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 3747);

create table tor_control_reply_code_fact (
  reply_code integer primary key,
  reply_class text not null,
  meaning text not null,
  source_name text not null,
  source_line integer not null
);

insert into tor_control_reply_code_fact(reply_code, reply_class, meaning, source_name, source_line) values
  (250, 'success', 'OK or data line', 'docs/tor-spec/17-control-protocol.md', 31), (251, 'success', 'descriptor accepted with explanation body', 'docs/tor-spec/17-control-protocol.md', 981), (451, 'transient_error', 'resource exhausted', 'docs/tor-spec/17-control-protocol.md', 210), (512, 'syntax_error', 'syntax error in command argument or missing arguments', 'docs/tor-spec/17-control-protocol.md', 210), (513, 'syntax_error', 'syntax error in configuration values or unrecognized value', 'docs/tor-spec/17-control-protocol.md', 31), (515, 'authentication_error', 'bad authentication', 'docs/tor-spec/17-control-protocol.md', 116), (551, 'operation_error', 'unable to write or internal/transient failure', 'docs/tor-spec/17-control-protocol.md', 136), (552, 'not_found', 'unrecognized option, event, signal, stream, circuit, or value', 'docs/tor-spec/17-control-protocol.md', 31), (553, 'semantic_error', 'impossible configuration setting', 'docs/tor-spec/17-control-protocol.md', 31), (554, 'semantic_error', 'invalid descriptor', 'docs/tor-spec/17-control-protocol.md', 981), (555, 'semantic_error', 'inappropriate stream state for attachment', 'docs/tor-spec/17-control-protocol.md', 958), (650, 'asynchronous_event', 'asynchronous event line', 'docs/tor-spec/17-control-protocol.md', 2415);

create table tor_control_signal_fact (
  signal_name text primary key,
  posix_alias text not null,
  effect_summary text not null,
  host_surface_status text not null,
  source_name text not null,
  source_line integer not null
);

insert into tor_control_signal_fact(signal_name, posix_alias, effect_summary, host_surface_status, source_name, source_line) values
  ('RELOAD', 'HUP', 'reload config items', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 150), ('SHUTDOWN', 'INT', 'controlled shutdown', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 150), ('DUMP', 'USR1', 'dump connection and circuit stats', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 150), ('DEBUG', 'USR2', 'switch logs to debug level', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 150), ('HALT', 'TERM', 'immediate shutdown', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 150), ('CLEARDNSCACHE', '', 'clear client-side DNS cache', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 152), ('NEWNYM', '', 'switch to clean circuits and clear client DNS cache', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 151), ('HEARTBEAT', '', 'emit unscheduled heartbeat log', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 152), ('DORMANT', '', 'enter dormant mode', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 152), ('ACTIVE', '', 'leave dormant mode', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 152);

create table tor_control_getinfo_key_fact (
  key_pattern text primary key,
  key_group text not null,
  value_kind text not null,
  host_surface_status text not null,
  source_name text not null,
  source_line integer not null
);

insert into tor_control_getinfo_key_fact(key_pattern, key_group, value_kind, host_surface_status, source_name, source_line) values
  ('version', 'software', 'version_string', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 282), ('config-file', 'configuration', 'path', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 286), ('config-defaults-file', 'configuration', 'path', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 288), ('config-text', 'configuration', 'text', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 293), ('exit-policy/default', 'exit_policy', 'policy_lines', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 297), ('exit-policy/reject-private/default', 'exit_policy', 'policy_lines', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 300), ('exit-policy/reject-private/relay', 'exit_policy', 'policy_lines', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 304), ('exit-policy/ipv4', 'exit_policy', 'policy_lines', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 312), ('exit-policy/ipv6', 'exit_policy', 'policy_lines', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 313), ('exit-policy/full', 'exit_policy', 'policy_lines', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 314), ('desc/id/<OR identity>', 'descriptor', 'server_descriptor', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 318), ('desc/name/<OR nickname>', 'descriptor', 'server_descriptor', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 318), ('md/all', 'microdescriptor', 'microdescriptor_set', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 324), ('md/id/<OR identity>', 'microdescriptor', 'microdescriptor', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 328), ('md/name/<OR nickname>', 'microdescriptor', 'microdescriptor', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 328), ('desc/download-enabled', 'descriptor', 'boolean', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 333), ('md/download-enabled', 'microdescriptor', 'boolean', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 336), ('dormant', 'runtime_state', 'integer', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 339), ('desc-annotations/id/<OR identity>', 'descriptor', 'annotation_text', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 343), ('extra-info/digest/<digest>', 'descriptor', 'extra_info_document', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 347), ('ns/id/<OR identity>', 'directory', 'router_status', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 351), ('ns/name/<OR nickname>', 'directory', 'router_status', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 351), ('ns/all', 'directory', 'router_status_set', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 362), ('ns/purpose/<purpose>', 'directory', 'router_status_set', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 367), ('desc/all-recent', 'descriptor', 'server_descriptor_set', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 377), ('network-status', 'directory', 'deprecated_removed', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 380), ('address-mappings/all', 'address_mapping', 'mapping_set_with_expiry', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 383), ('address-mappings/config', 'address_mapping', 'mapping_set_with_expiry', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 384), ('address-mappings/cache', 'address_mapping', 'mapping_set_with_expiry', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 385), ('address-mappings/control', 'address_mapping', 'mapping_set_with_expiry', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 386), ('addr-mappings/*', 'address_mapping', 'deprecated_mapping_set_without_expiry', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 397), ('address', 'network_identity', 'ip_address', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 401), ('address/v4', 'network_identity', 'ipv4_address', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 404), ('address/v6', 'network_identity', 'ipv6_address', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 405), ('fingerprint', 'relay_identity', 'fingerprint_text', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 409), ('circuit-status', 'circuit', 'circ_event_lines', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 413), ('stream-status', 'stream', 'stream_event_lines', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 419), ('orconn-status', 'or_connection', 'orconn_event_lines', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 423), ('entry-guards', 'guard', 'guard_status_lines', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 434), ('traffic/read', 'traffic', 'byte_count', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 462), ('traffic/written', 'traffic', 'byte_count', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 464), ('uptime', 'runtime_state', 'seconds', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 466), ('accounting/*', 'accounting', 'accounting_state', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 469), ('config/names', 'configuration', 'option_schema_lines', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 486), ('config/defaults', 'configuration', 'option_default_lines', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 499), ('info/names', 'introspection', 'getinfo_schema_lines', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 507), ('events/names', 'introspection', 'event_name_list', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 517), ('features/names', 'introspection', 'feature_name_list', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 521), ('signal/names', 'introspection', 'signal_name_list', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 525), ('ip-to-country/*', 'geoip', 'country_code', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 529), ('process/*', 'process', 'process_metadata', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 538), ('dir/status-vote/current/consensus', 'directory', 'consensus_document', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 547), ('dir/status-vote/current/consensus-microdesc', 'directory', 'microdesc_consensus_document', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 548), ('dir/status/*', 'directory', 'directory_status_document', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 549), ('dir/server/*', 'directory', 'directory_server_document', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 553), ('status/*', 'status', 'status_value', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 573), ('net/listeners/*', 'listener', 'listener_addresses', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 613), ('dir-usage', 'directory', 'removed_usage_counters', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 674), ('bw-event-cache', 'bandwidth', 'recent_bw_tuples', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 686), ('consensus/*', 'directory', 'consensus_time', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 694), ('hs/client/desc/id/<ADDR>', 'onion_service', 'client_descriptor', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 701), ('hs/service/desc/id/<ADDR>', 'onion_service', 'service_descriptor', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 714), ('onions/current', 'onion_service', 'current_onion_service_list', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 727), ('onions/detached', 'onion_service', 'detached_onion_service_list', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 728), ('network-liveness', 'network', 'up_down', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 739), ('downloads/*', 'download_status', 'serialized_download_status', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 743), ('sr/current', 'shared_random', 'base64_value', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 854), ('sr/previous', 'shared_random', 'base64_value', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 855), ('current-time/local', 'clock', 'datetime', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 860), ('current-time/utc', 'clock', 'datetime', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 861), ('stats/ntor/*', 'statistics', 'ntor_rephist_value', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 865), ('stats/tap/*', 'statistics', 'tap_rephist_value', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 870), ('config-can-saveconf', 'configuration', 'boolean', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 875), ('limits/max-mem-in-queues', 'resource_limit', 'byte_count', 'unsupported', 'docs/tor-spec/17-control-protocol.md', 879);

create table tor_control_bootstrap_phase_fact (
  progress integer primary key,
  stage integer not null,
  tag text not null unique,
  summary text not null,
  source_name text not null,
  source_line integer not null
);

insert into tor_control_bootstrap_phase_fact(progress, stage, tag, summary, source_name, source_line) values
  (0, 1, 'starting', 'Starting', 'docs/tor-spec/17-control-protocol.md', 1813), (1, 1, 'conn_pt', 'Connecting to pluggable transport', 'docs/tor-spec/17-control-protocol.md', 1817), (2, 1, 'conn_done_pt', 'Connected to pluggable transport', 'docs/tor-spec/17-control-protocol.md', 1825), (3, 1, 'conn_proxy', 'Connecting to proxy', 'docs/tor-spec/17-control-protocol.md', 1833), (4, 1, 'conn_done_proxy', 'Connected to proxy', 'docs/tor-spec/17-control-protocol.md', 1841), (5, 1, 'conn', 'Connecting to a relay', 'docs/tor-spec/17-control-protocol.md', 1849), (10, 1, 'conn_done', 'Connected to a relay', 'docs/tor-spec/17-control-protocol.md', 1858), (14, 1, 'handshake', 'Handshaking with a relay', 'docs/tor-spec/17-control-protocol.md', 1864), (15, 1, 'handshake_done', 'Handshake with a relay done', 'docs/tor-spec/17-control-protocol.md', 1870), (20, 2, 'onehop_create', 'Establishing an encrypted directory connection', 'docs/tor-spec/17-control-protocol.md', 1880), (25, 2, 'requesting_status', 'Asking for networkstatus consensus', 'docs/tor-spec/17-control-protocol.md', 1888), (30, 2, 'loading_status', 'Loading networkstatus consensus', 'docs/tor-spec/17-control-protocol.md', 1896), (40, 2, 'loading_keys', 'Loading authority key certs', 'docs/tor-spec/17-control-protocol.md', 1906), (45, 2, 'requesting_descriptors', 'Asking for relay descriptors', 'docs/tor-spec/17-control-protocol.md', 1910), (50, 2, 'loading_descriptors', 'Loading relay descriptors', 'docs/tor-spec/17-control-protocol.md', 1920), (75, 2, 'enough_dirinfo', 'Loaded enough directory info to build circuits', 'docs/tor-spec/17-control-protocol.md', 1928), (76, 3, 'ap_conn_pt', 'Connecting to pluggable transport to build circuits', 'docs/tor-spec/17-control-protocol.md', 1938), (77, 3, 'ap_conn_done_pt', 'Connected to pluggable transport to build circuits', 'docs/tor-spec/17-control-protocol.md', 1947), (78, 3, 'ap_conn_proxy', 'Connecting to proxy to build circuits', 'docs/tor-spec/17-control-protocol.md', 1955), (79, 3, 'ap_conn_done_proxy', 'Connected to proxy to build circuits', 'docs/tor-spec/17-control-protocol.md', 1963), (80, 3, 'ap_conn', 'Connecting to a relay to build circuits', 'docs/tor-spec/17-control-protocol.md', 1971), (85, 3, 'ap_conn_done', 'Connected to a relay to build circuits', 'docs/tor-spec/17-control-protocol.md', 1979), (89, 3, 'ap_handshake', 'Finishing handshake with a relay to build circuits', 'docs/tor-spec/17-control-protocol.md', 1987), (90, 3, 'ap_handshake_done', 'Handshake finished with a relay to build circuits', 'docs/tor-spec/17-control-protocol.md', 1995), (95, 3, 'circuit_create', 'Establishing a Tor circuit', 'docs/tor-spec/17-control-protocol.md', 2003), (100, 3, 'done', 'Done', 'docs/tor-spec/17-control-protocol.md', 2017);

create table tor_control_status_action_fact (
  status_type text not null,
  action_name text not null,
  severity_set text not null,
  argument_set text not null,
  source_name text not null,
  source_line integer not null,
  primary key (status_type, action_name)
);

insert into tor_control_status_action_fact(status_type, action_name, severity_set, argument_set, source_name, source_line) values
  ('STATUS_GENERAL', 'CLOCK_JUMPED', 'NOTICE|WARN', 'TIME', 'docs/tor-spec/17-control-protocol.md', 2945), ('STATUS_GENERAL', 'DANGEROUS_VERSION', 'NOTICE|WARN', 'CURRENT|REASON|RECOMMENDED', 'docs/tor-spec/17-control-protocol.md', 2951), ('STATUS_GENERAL', 'TOO_MANY_CONNECTIONS', 'WARN', 'CURRENT', 'docs/tor-spec/17-control-protocol.md', 2958), ('STATUS_GENERAL', 'BUG', 'WARN', 'REASON', 'docs/tor-spec/17-control-protocol.md', 2962), ('STATUS_GENERAL', 'CLOCK_SKEW', 'WARN', 'SKEW|MIN_SKEW|SOURCE', 'docs/tor-spec/17-control-protocol.md', 2966), ('STATUS_GENERAL', 'BAD_LIBEVENT', 'WARN', 'METHOD|VERSION|BADNESS|RECOVERED', 'docs/tor-spec/17-control-protocol.md', 2973), ('STATUS_GENERAL', 'DIR_ALL_UNREACHABLE', 'WARN', '', 'docs/tor-spec/17-control-protocol.md', 2981), ('STATUS_CLIENT', 'BOOTSTRAP', 'NOTICE|WARN', 'PROGRESS|TAG|SUMMARY|WARNING|REASON|COUNT|RECOMMENDATION|HOST|HOSTADDR', 'docs/tor-spec/17-control-protocol.md', 2987), ('STATUS_CLIENT', 'ENOUGH_DIR_INFO', 'NOTICE', '', 'docs/tor-spec/17-control-protocol.md', 3042), ('STATUS_CLIENT', 'NOT_ENOUGH_DIR_INFO', 'WARN', '', 'docs/tor-spec/17-control-protocol.md', 3050), ('STATUS_CLIENT', 'CIRCUIT_ESTABLISHED', 'NOTICE', '', 'docs/tor-spec/17-control-protocol.md', 3058), ('STATUS_CLIENT', 'CIRCUIT_NOT_ESTABLISHED', 'WARN', 'REASON', 'docs/tor-spec/17-control-protocol.md', 3069), ('STATUS_CLIENT', 'CONSENSUS_ARRIVED', 'NOTICE', '', 'docs/tor-spec/17-control-protocol.md', 3079), ('STATUS_CLIENT', 'DANGEROUS_PORT', 'WARN', 'PORT|RESULT', 'docs/tor-spec/17-control-protocol.md', 3082);

create table tor_bandwidth_file_version_fact (
  format_version text primary key,
  status text not null,
  semantic_delta text not null,
  source_name text not null,
  source_line integer not null
);

insert into tor_bandwidth_file_version_fact(format_version, status, semantic_delta, source_name, source_line) values
  ('1.0.0', 'legacy', 'timestamp plus relay lines; all Tor versions consume it', 'docs/tor-spec/19-bandwidth-file.md', 1069), ('1.1.0', 'compatible', 'adds header metadata and documents sbws/torflow relay keys', 'docs/tor-spec/19-bandwidth-file.md', 1071), ('1.2.0', 'compatible', 'adds eligible relay thresholds, countries, header statistics, and relay bandwidth variants', 'docs/tor-spec/19-bandwidth-file.md', 1074), ('1.4.0', 'compatible', 'adds monitoring keys and diagnostic relay lines marked vote=0', 'docs/tor-spec/19-bandwidth-file.md', 1084), ('1.5.0', 'compatible', 'removes recent_measurement_attempt_count header key', 'docs/tor-spec/19-bandwidth-file.md', 1094), ('1.6.0', 'compatible', 'adds congestion-control stream event keys', 'docs/tor-spec/19-bandwidth-file.md', 1095), ('1.7.0', 'compatible', 'adds stream ratio relay keys and network-average header keys', 'docs/tor-spec/19-bandwidth-file.md', 1096), ('1.8.0', 'compatible', 'adds dirauth_nickname header key', 'docs/tor-spec/19-bandwidth-file.md', 1098), ('1.9.0', 'compatible', 'allows node_id without a leading dollar sign', 'docs/tor-spec/19-bandwidth-file.md', 1099);

create table tor_bandwidth_file_grammar_fact (
  grammar_name text primary key,
  expression text not null,
  source_name text not null,
  source_line integer not null
);

insert into tor_bandwidth_file_grammar_fact(grammar_name, expression, source_name, source_line) values
  ('Line', 'ArgumentChar* NL', 'docs/tor-spec/19-bandwidth-file.md', 42), ('RelayLine', 'KeyValue (SP KeyValue)* NL', 'docs/tor-spec/19-bandwidth-file.md', 43), ('HeaderLine', 'KeyValue NL', 'docs/tor-spec/19-bandwidth-file.md', 44), ('KeyValue', 'Key "=" Value', 'docs/tor-spec/19-bandwidth-file.md', 45), ('Key', '(KeywordChar | "_")+', 'docs/tor-spec/19-bandwidth-file.md', 46), ('Value', 'ArgumentCharValue+', 'docs/tor-spec/19-bandwidth-file.md', 47), ('ArgumentCharValue', 'printing ASCII except NL and SP', 'docs/tor-spec/19-bandwidth-file.md', 48), ('Terminator', '"=====" or "===="; generators SHOULD use 5 characters', 'docs/tor-spec/19-bandwidth-file.md', 49), ('Timestamp', 'Int', 'docs/tor-spec/19-bandwidth-file.md', 51), ('Bandwidth', 'Int', 'docs/tor-spec/19-bandwidth-file.md', 52), ('MasterKey', 'base64 Ed25519 public key without padding', 'docs/tor-spec/19-bandwidth-file.md', 53), ('CountryCode', 'ISO 3166-1 alpha-2 plus ZZ', 'docs/tor-spec/19-bandwidth-file.md', 55), ('CountryCodeList', 'CountryCode (, CountryCode)*', 'docs/tor-spec/19-bandwidth-file.md', 58);

create table tor_bandwidth_file_key_fact (
  section_name text not null,
  key_name text not null,
  value_type text not null,
  cardinality text not null,
  introduced_version text not null,
  removed_version text not null,
  semantic_role text not null,
  source_name text not null,
  source_line integer not null,
  primary key (section_name, key_name)
);

insert into tor_bandwidth_file_key_fact(section_name, key_name, value_type, cardinality, introduced_version, removed_version, semantic_role, source_name, source_line) values
  ('header', 'timestamp', 'Timestamp', 'exactly_once_at_start', '1.0.0', '', 'most recent generator bandwidth result Unix epoch seconds', 'docs/tor-spec/19-bandwidth-file.md', 96), ('header', 'version', 'version_number', 'zero_or_one_second_position', '1.1.0', '', 'specification document format version; absent means 1.0.0', 'docs/tor-spec/19-bandwidth-file.md', 110), ('header', 'software', 'Value', 'zero_or_one', '1.1.0', '', 'generator software name; absent means torflow for 1.0.0', 'docs/tor-spec/19-bandwidth-file.md', 120), ('header', 'software_version', 'Value', 'zero_or_one', '1.1.0', '', 'generator software version', 'docs/tor-spec/19-bandwidth-file.md', 130), ('header', 'file_created', 'DateTime', 'zero_or_one', '1.1.0', '', 'file creation timestamp', 'docs/tor-spec/19-bandwidth-file.md', 138), ('header', 'generator_started', 'DateTime', 'zero_or_one', '1.1.0', '', 'generator start timestamp', 'docs/tor-spec/19-bandwidth-file.md', 146), ('header', 'earliest_bandwidth', 'DateTime', 'zero_or_one', '1.1.0', '', 'first relay bandwidth timestamp', 'docs/tor-spec/19-bandwidth-file.md', 154), ('header', 'latest_bandwidth', 'DateTime', 'zero_or_one', '1.1.0', '', 'most recent generator result; must match timestamp', 'docs/tor-spec/19-bandwidth-file.md', 162), ('header', 'number_eligible_relays', 'Int', 'zero_or_one', '1.2.0', '', 'relays with enough measurements', 'docs/tor-spec/19-bandwidth-file.md', 174), ('header', 'minimum_percent_eligible_relays', 'Int', 'zero_or_one', '1.2.0', '', 'minimum percentage of consensus relays that should be included', 'docs/tor-spec/19-bandwidth-file.md', 182), ('header', 'number_consensus_relays', 'Int', 'zero_or_one', '1.2.0', '', 'number of relays in the consensus', 'docs/tor-spec/19-bandwidth-file.md', 196), ('header', 'percent_eligible_relays', 'Int', 'zero_or_one', '1.2.0', '', 'number_eligible_relays percentage of number_consensus_relays', 'docs/tor-spec/19-bandwidth-file.md', 204), ('header', 'minimum_number_eligible_relays', 'Int', 'zero_or_one', '1.2.0', '', 'minimum relays that should be included', 'docs/tor-spec/19-bandwidth-file.md', 216), ('header', 'scanner_country', 'CountryCode', 'zero_or_one', '1.2.0', '', 'country where generator runs', 'docs/tor-spec/19-bandwidth-file.md', 229), ('header', 'destinations_countries', 'CountryCodeList', 'zero_or_one', '1.2.0', '', 'countries where measurement destinations are located', 'docs/tor-spec/19-bandwidth-file.md', 237), ('header', 'recent_consensus_count', 'Int', 'zero_or_one', '1.4.0', '', 'consensuses seen in last data_period days', 'docs/tor-spec/19-bandwidth-file.md', 247), ('header', 'recent_priority_list_count', 'Int', 'zero_or_one', '1.4.0', '', 'priority lists created in last data_period days', 'docs/tor-spec/19-bandwidth-file.md', 261), ('header', 'recent_priority_relay_count', 'Int', 'zero_or_one', '1.4.0', '', 'relays prioritized in last data_period days', 'docs/tor-spec/19-bandwidth-file.md', 278), ('header', 'recent_measurement_attempt_count', 'Int', 'zero_or_one', '1.4.0', '1.5.0', 'relay measurement queue attempts in last data_period days', 'docs/tor-spec/19-bandwidth-file.md', 295), ('header', 'recent_measurement_failure_count', 'Int', 'zero_or_one', '1.4.0', '', 'measurement attempts that failed in last data_period days', 'docs/tor-spec/19-bandwidth-file.md', 307), ('header', 'recent_measurements_excluded_error_count', 'Int', 'zero_or_one', '1.4.0', '', 'relays with no successful recent measurements', 'docs/tor-spec/19-bandwidth-file.md', 315), ('header', 'recent_measurements_excluded_near_count', 'Int', 'zero_or_one', '1.4.0', '', 'relays whose successful measurements were too close in time', 'docs/tor-spec/19-bandwidth-file.md', 325), ('header', 'recent_measurements_excluded_old_count', 'Int', 'zero_or_one', '1.4.0', '', 'relays whose successful measurements are too old', 'docs/tor-spec/19-bandwidth-file.md', 335), ('header', 'recent_measurements_excluded_few_count', 'Int', 'zero_or_one', '1.4.0', '', 'relays with too few recent successful measurements', 'docs/tor-spec/19-bandwidth-file.md', 347), ('header', 'time_to_report_half_network', 'Int', 'zero_or_one', '1.4.0', '', 'seconds to report measurements for half the network', 'docs/tor-spec/19-bandwidth-file.md', 359), ('header', 'tor_version', 'version_number', 'zero_or_one', '1.4.0', '', 'Tor process version controlled by generator', 'docs/tor-spec/19-bandwidth-file.md', 369), ('header', 'mu', 'Int', 'zero_or_one', '1.7.0', '', 'network stream bandwidth average', 'docs/tor-spec/19-bandwidth-file.md', 377), ('header', 'muf', 'Int', 'zero_or_one', '1.7.0', '', 'filtered network stream bandwidth average', 'docs/tor-spec/19-bandwidth-file.md', 385), ('header', 'dirauth_nickname', 'Value', 'zero_or_one', '1.8.0', '', 'directory authority nickname publishing the file', 'docs/tor-spec/19-bandwidth-file.md', 397), ('header', 'terminator', 'Terminator', 'zero_or_one', '1.1.0', '', 'header list terminator; 5 characters preferred', 'docs/tor-spec/19-bandwidth-file.md', 417),
  ('relay', 'node_id', 'hexdigest', 'exactly_once', '1.0.0', '', 'relay RSA identity fingerprint; required by current Tor', 'docs/tor-spec/19-bandwidth-file.md', 761), ('relay', 'master_key_ed25519', 'MasterKey', 'zero_or_one', '1.1.0', '', 'relay master Ed25519 identity key', 'docs/tor-spec/19-bandwidth-file.md', 779), ('relay', 'bw', 'Bandwidth', 'exactly_once', '1.0.0', '', 'relay bandwidth in kilobytes per second; generators should not produce zero', 'docs/tor-spec/19-bandwidth-file.md', 789), ('relay', 'nick', 'nickname', 'exactly_once', '1.1.0', '', 'relay nickname', 'docs/tor-spec/19-bandwidth-file.md', 455), ('relay', 'rtt', 'Int', 'zero_or_one', '1.1.0', '', 'round trip time in milliseconds for one byte', 'docs/tor-spec/19-bandwidth-file.md', 463), ('relay', 'time', 'DateWsTime', 'exactly_once', '1.1.0', '', 'timestamp when last bandwidth was obtained', 'docs/tor-spec/19-bandwidth-file.md', 471), ('relay', 'success', 'Int', 'zero_or_one', '1.1.0', '', 'successful relay measurements count', 'docs/tor-spec/19-bandwidth-file.md', 479), ('relay', 'error_circ', 'Int', 'zero_or_one', '1.1.0', '', 'circuit failure measurement count', 'docs/tor-spec/19-bandwidth-file.md', 487), ('relay', 'error_stream', 'Int', 'zero_or_one', '1.1.0', '', 'stream failure measurement count', 'docs/tor-spec/19-bandwidth-file.md', 495), ('relay', 'error_destination', 'Int', 'zero_or_one', '1.4.0', '', 'destination unavailable measurement failures', 'docs/tor-spec/19-bandwidth-file.md', 503), ('relay', 'error_second_relay', 'Int', 'zero_or_one', '1.4.0', '', 'failure to find second relay for test circuit', 'docs/tor-spec/19-bandwidth-file.md', 511), ('relay', 'error_misc', 'Int', 'zero_or_one', '1.1.0', '', 'other measurement failure count', 'docs/tor-spec/19-bandwidth-file.md', 519), ('relay', 'bw_mean', 'Int', 'zero_or_one', '1.2.0', '', 'measured bandwidth mean bytes per second', 'docs/tor-spec/19-bandwidth-file.md', 527), ('relay', 'bw_median', 'Int', 'zero_or_one', '1.2.0', '', 'measured bandwidth median bytes per second', 'docs/tor-spec/19-bandwidth-file.md', 535), ('relay', 'desc_bw_avg', 'Int', 'zero_or_one', '1.2.0', '', 'descriptor average bandwidth bytes per second', 'docs/tor-spec/19-bandwidth-file.md', 543), ('relay', 'desc_bw_obs_last', 'Int', 'zero_or_one', '1.2.0', '', 'last descriptor observed bandwidth bytes per second', 'docs/tor-spec/19-bandwidth-file.md', 551), ('relay', 'desc_bw_obs_mean', 'Int', 'zero_or_one', '1.2.0', '', 'descriptor observed bandwidth mean bytes per second', 'docs/tor-spec/19-bandwidth-file.md', 559), ('relay', 'desc_bw_bur', 'Int', 'zero_or_one', '1.2.0', '', 'descriptor burst bandwidth bytes per second', 'docs/tor-spec/19-bandwidth-file.md', 567), ('relay', 'consensus_bandwidth', 'Int', 'zero_or_one', '1.2.0', '', 'consensus bandwidth bytes per second', 'docs/tor-spec/19-bandwidth-file.md', 575), ('relay', 'consensus_bandwidth_is_unmeasured', 'Bool', 'zero_or_one', '1.2.0', '', 'whether consensus bandwidth lacks three or more bandwidth authorities', 'docs/tor-spec/19-bandwidth-file.md', 583), ('relay', 'relay_in_recent_consensus_count', 'Int', 'zero_or_one', '1.4.0', '', 'relay appearances in consensus in last data_period days', 'docs/tor-spec/19-bandwidth-file.md', 591), ('relay', 'relay_recent_priority_list_count', 'Int', 'zero_or_one', '1.4.0', '', 'relay prioritization count in last data_period days', 'docs/tor-spec/19-bandwidth-file.md', 599), ('relay', 'relay_recent_measurement_attempt_count', 'Int', 'zero_or_one', '1.4.0', '', 'relay measurement attempts in last data_period days', 'docs/tor-spec/19-bandwidth-file.md', 607), ('relay', 'relay_recent_measurement_failure_count', 'Int', 'zero_or_one', '1.4.0', '', 'relay failed measurement attempts in last data_period days', 'docs/tor-spec/19-bandwidth-file.md', 615), ('relay', 'relay_recent_measurements_excluded_error_count', 'Int', 'zero_or_one', '1.4.0', '', 'recent relay measurement attempts that failed', 'docs/tor-spec/19-bandwidth-file.md', 623), ('relay', 'relay_recent_measurements_excluded_near_count', 'Int', 'zero_or_one', '1.4.0', '', 'recent successful measurements ignored because too near', 'docs/tor-spec/19-bandwidth-file.md', 633), ('relay', 'relay_recent_measurements_excluded_old_count', 'Int', 'zero_or_one', '1.4.0', '', 'successful measurements too old', 'docs/tor-spec/19-bandwidth-file.md', 643), ('relay', 'relay_recent_measurements_excluded_few_count', 'Int', 'zero_or_one', '1.4.0', '', 'successful measurements ignored because too few', 'docs/tor-spec/19-bandwidth-file.md', 655), ('relay', 'under_min_report', 'bool', 'zero_or_one', '1.4.0', '', 'not enough eligible relays; authorities may not vote on this relay', 'docs/tor-spec/19-bandwidth-file.md', 667), ('relay', 'unmeasured', 'bool', 'zero_or_one', '1.4.0', '', 'relay was not successfully measured; generators must set bw=1', 'docs/tor-spec/19-bandwidth-file.md', 679), ('relay', 'vote', 'bool', 'zero_or_one', '1.4.0', '', '0 means authorities should ignore relay entry; 1 or absent means use bw', 'docs/tor-spec/19-bandwidth-file.md', 691), ('relay', 'xoff_recv', 'Int', 'zero_or_one', '1.6.0', '', 'XOFF_RECV stream events while measuring relay', 'docs/tor-spec/19-bandwidth-file.md', 705), ('relay', 'xoff_sent', 'Int', 'zero_or_one', '1.6.0', '', 'XOFF_SENT stream events while measuring relay', 'docs/tor-spec/19-bandwidth-file.md', 713), ('relay', 'r_strm', 'Float', 'zero_or_one', '1.7.0', '', 'stream ratio for relay', 'docs/tor-spec/19-bandwidth-file.md', 721), ('relay', 'r_strm_filt', 'Float', 'zero_or_one', '1.7.0', '', 'filtered stream ratio for relay', 'docs/tor-spec/19-bandwidth-file.md', 729);

create table tor_bandwidth_file_rule_fact (
  rule_name text primary key,
  rule_kind text not null,
  rule_text text not null,
  source_name text not null,
  source_line integer not null
);

insert into tor_bandwidth_file_rule_fact(rule_name, rule_kind, rule_text, source_name, source_line) values
  ('file_sections', 'parse', 'header list exactly once, then zero or more relay lines; ignore file if sections missing', 'docs/tor-spec/19-bandwidth-file.md', 72), ('header_duplicate_key', 'parse', 'header MUST NOT contain duplicate KeyValue keys; parser SHOULD choose arbitrary line if duplicated', 'docs/tor-spec/19-bandwidth-file.md', 405), ('header_unknown_key', 'parse', 'unknown header KeyValue line MUST be ignored', 'docs/tor-spec/19-bandwidth-file.md', 407), ('relay_duplicate_key', 'parse', 'relay line MUST NOT contain duplicate keys; parser SHOULD choose arbitrary value if duplicated', 'docs/tor-spec/19-bandwidth-file.md', 753), ('relay_duplicate_identity', 'parse', 'multiple RelayLines per relay identity SHOULD warn; parser may reject, choose arbitrary, or ignore both', 'docs/tor-spec/19-bandwidth-file.md', 755), ('relay_unknown_key', 'parse', 'unknown relay extra material MUST be ignored', 'docs/tor-spec/19-bandwidth-file.md', 757), ('node_id_current_required', 'parse', 'current Tor ignores master_key_ed25519, so node_id MUST be present', 'docs/tor-spec/19-bandwidth-file.md', 773), ('node_id_dollar_optional_1_9_0', 'parse', 'version 1.9.0 allows node_id without leading dollar sign', 'docs/tor-spec/19-bandwidth-file.md', 777), ('minimum_percent_1_3_or_earlier', 'vote', 'if threshold not reached, versions 1.3.0 and earlier SHOULD NOT contain relay lines', 'docs/tor-spec/19-bandwidth-file.md', 188), ('minimum_percent_1_4_or_later', 'vote', 'if threshold not reached, versions 1.4.0 and later SHOULD include diagnostics marked not voteable', 'docs/tor-spec/19-bandwidth-file.md', 190), ('under_min_report_behavior', 'vote', 'under_min_report=1 means not enough eligible relays; do not change bw for compatibility', 'docs/tor-spec/19-bandwidth-file.md', 671), ('unmeasured_behavior', 'vote', 'unmeasured=1 means not successfully measured; generator MUST set bw=1', 'docs/tor-spec/19-bandwidth-file.md', 683), ('vote_zero_behavior', 'vote', 'vote=0 means authorities SHOULD ignore relay entry; vote absent or 1 means use bw', 'docs/tor-spec/19-bandwidth-file.md', 695), ('legacy_vote_zero_gap', 'compatibility', 'Tor 0.4.0.3-alpha, 0.3.5.8, 0.3.4.11 and earlier do not understand vote=0', 'docs/tor-spec/19-bandwidth-file.md', 1107), ('atomic_write', 'write', 'write bandwidth files atomically using temp path then rename', 'docs/tor-spec/19-bandwidth-file.md', 431), ('zero_total_scaling', 'scaling', 'if total bandwidth is zero, give all relays equal bandwidths', 'docs/tor-spec/19-bandwidth-file.md', 958), ('zero_scaled_round_up', 'scaling', 'if scaled bandwidth is zero, round up to one', 'docs/tor-spec/19-bandwidth-file.md', 960), ('linear_scaling_quota', 'scaling', 'relay quota = total measured bandwidth in all votes / relays with measured bandwidth votes', 'docs/tor-spec/19-bandwidth-file.md', 970), ('linear_scaling_vote_quota', 'scaling', 'vote quota = relay quota * number of relays measured by authority', 'docs/tor-spec/19-bandwidth-file.md', 976), ('linear_scaling_factor', 'scaling', 'scaling factor = vote quota / total unscaled measured bandwidth in upcoming vote', 'docs/tor-spec/19-bandwidth-file.md', 980), ('linear_scaling_apply', 'scaling', 'scaled bandwidth = unscaled measured bandwidth * scaling factor', 'docs/tor-spec/19-bandwidth-file.md', 984), ('torflow_filtered_bandwidth', 'aggregation', 'bw_filt_i = mean(max(mean(bw_j), bw_j))', 'docs/tor-spec/19-bandwidth-file.md', 1001), ('torflow_network_averages', 'aggregation', 'bw_avg_filt = sum filtered bandwidth / n; bw_avg_strm = sum measured bandwidth / n', 'docs/tor-spec/19-bandwidth-file.md', 1010), ('torflow_ratios', 'aggregation', 'r_filt_i = bw_filt_i / bw_avg_filt; r_strm_i = bw_i / bw_avg_strm', 'docs/tor-spec/19-bandwidth-file.md', 1025), ('torflow_final_ratio', 'aggregation', 'r_i = max(r_filt_i, r_strm_i)', 'docs/tor-spec/19-bandwidth-file.md', 1037), ('torflow_scaled_bandwidth', 'aggregation', 'bw_new_i = r_i * bw_obs_i', 'docs/tor-spec/19-bandwidth-file.md', 1045);

create table media_format_fact (
  format_name text primary key,
  media_kind text not null,
  container_kind text not null,
  header_decode_status text not null,
  payload_decode_status text not null,
  encode_status text not null
);

insert into media_format_fact(format_name, media_kind, container_kind, header_decode_status, payload_decode_status, encode_status) values
  ('png', 'image', 'chunked', 'supported', 'supported', 'unsupported'), ('jpeg', 'image', 'marker-segment', 'supported', 'supported', 'unsupported'), ('jxl-codestream', 'image', 'codestream', 'detected', 'unsupported', 'unsupported'), ('jxl-container', 'image', 'box-container', 'detected', 'unsupported', 'unsupported'), ('tga', 'image', 'fixed-header', 'supported', 'supported', 'supported'), ('runtime-image', 'image', 'canonical-owned', 'supported', 'supported', 'supported'), ('ivf', 'video', 'fixed-header-frame-records', 'supported', 'container-only', 'unsupported'), ('webm-video', 'video', 'ebml', 'supported', 'container-only', 'unsupported'), ('webm-audio', 'audio', 'ebml', 'supported', 'packet-only', 'unsupported');

create table media_codec_fact (
  codec_name text primary key,
  media_kind text not null,
  wire_id text not null,
  payload_decode_status text not null
);

insert into media_codec_fact(codec_name, media_kind, wire_id, payload_decode_status) values
  ('vp8', 'video', 'VP80|V_VP8', 'unsupported'), ('opus', 'audio', 'A_OPUS', 'packet-only'), ('vorbis', 'audio', 'A_VORBIS', 'packet-only'), ('rgba8', 'image', '1', 'supported');

create table media_format_codec_fact (
  format_name text not null references media_format_fact(format_name),
  codec_name text not null references media_codec_fact(codec_name),
  wire_id text not null,
  primary key (format_name, codec_name, wire_id)
);

insert into media_format_codec_fact(format_name, codec_name, wire_id) values
  ('ivf', 'vp8', 'VP80'), ('webm-video', 'vp8', 'V_VP8'), ('webm-audio', 'opus', 'A_OPUS'), ('webm-audio', 'vorbis', 'A_VORBIS'), ('runtime-image', 'rgba8', '1');

create table media_codec_constant_fact (
  codec_name text not null references media_codec_fact(codec_name),
  symbol_name text not null,
  constant_group text not null,
  value_text text not null,
  value_integer integer not null,
  source_name text not null,
  source_line integer not null,
  primary key (codec_name, symbol_name)
);

insert into media_codec_constant_fact(codec_name, symbol_name, constant_group, value_text, value_integer, source_name, source_line) values
  ('vp8', 'VP8_FRAME_TAG_SIZE', 'frame_tag', '3', 3, 'kernel/x86_64/media/vp8_constants.inc', 6), ('vp8', 'VP8_KEY_FRAME_HEADER_SIZE', 'frame_tag', '10', 10, 'kernel/x86_64/media/vp8_constants.inc', 7), ('vp8', 'VP8_FRAME_TYPE_KEY', 'frame_tag', '0', 0, 'kernel/x86_64/media/vp8_constants.inc', 8), ('vp8', 'VP8_FRAME_TYPE_INTER', 'frame_tag', '1', 1, 'kernel/x86_64/media/vp8_constants.inc', 9), ('vp8', 'VP8_FRAME_TYPE_MASK', 'frame_tag', '0x01', 1, 'kernel/x86_64/media/vp8_constants.inc', 10), ('vp8', 'VP8_VERSION_MASK', 'frame_tag', '0x0e', 14, 'kernel/x86_64/media/vp8_constants.inc', 11), ('vp8', 'VP8_VERSION_SHIFT', 'frame_tag', '1', 1, 'kernel/x86_64/media/vp8_constants.inc', 12), ('vp8', 'VP8_VERSION_MAX', 'frame_tag', '3', 3, 'kernel/x86_64/media/vp8_constants.inc', 13), ('vp8', 'VP8_SHOW_FRAME_MASK', 'frame_tag', '0x10', 16, 'kernel/x86_64/media/vp8_constants.inc', 14), ('vp8', 'VP8_SHOW_FRAME_SHIFT', 'frame_tag', '4', 4, 'kernel/x86_64/media/vp8_constants.inc', 15), ('vp8', 'VP8_SHOW_FRAME_VISIBLE', 'frame_tag', '1', 1, 'kernel/x86_64/media/vp8_constants.inc', 16), ('vp8', 'VP8_FIRST_PARTITION_LEN_SHIFT', 'frame_tag', '5', 5, 'kernel/x86_64/media/vp8_constants.inc', 17), ('vp8', 'VP8_FIRST_PARTITION_LEN_BITS', 'frame_tag', '19', 19, 'kernel/x86_64/media/vp8_constants.inc', 18), ('vp8', 'VP8_FIRST_PARTITION_LEN_MAX', 'frame_tag', '0x7ffff', 524287, 'kernel/x86_64/media/vp8_constants.inc', 19), ('vp8', 'VP8_START_CODE_OFFSET', 'key_frame_header', '3', 3, 'kernel/x86_64/media/vp8_constants.inc', 20), ('vp8', 'VP8_KEY_FRAME_START_CODE_0', 'key_frame_header', '0x9d', 157, 'kernel/x86_64/media/vp8_constants.inc', 21), ('vp8', 'VP8_KEY_FRAME_START_CODE_1', 'key_frame_header', '0x01', 1, 'kernel/x86_64/media/vp8_constants.inc', 22), ('vp8', 'VP8_KEY_FRAME_START_CODE_2', 'key_frame_header', '0x2a', 42, 'kernel/x86_64/media/vp8_constants.inc', 23), ('vp8', 'VP8_DIMENSION_MASK', 'key_frame_header', '0x3fff', 16383, 'kernel/x86_64/media/vp8_constants.inc', 24), ('vp8', 'VP8_DIMENSION_WIDTH_OFFSET', 'key_frame_header', '6', 6, 'kernel/x86_64/media/vp8_constants.inc', 25), ('vp8', 'VP8_DIMENSION_HEIGHT_OFFSET', 'key_frame_header', '8', 8, 'kernel/x86_64/media/vp8_constants.inc', 26),
  ('vp8', 'VP8_BOOL_INITIAL_BYTES', 'bool_reader', '2', 2, 'kernel/x86_64/media/vp8_constants.inc', 52), ('vp8', 'VP8_BOOL_PROBABILITY_HALF', 'bool_reader', '128', 128, 'kernel/x86_64/media/vp8_constants.inc', 53), ('vp8', 'VP8_BOOL_BYTE_BITS', 'bool_reader', '8', 8, 'kernel/x86_64/media/vp8_constants.inc', 54), ('vp8', 'VP8_BOOL_RANGE_INIT', 'bool_reader', '255', 255, 'kernel/x86_64/media/vp8_constants.inc', 55), ('vp8', 'VP8_BOOL_RANGE_RENORM_MIN', 'bool_reader', '128', 128, 'kernel/x86_64/media/vp8_constants.inc', 56), ('vp8', 'VP8_BOOL_PROBABILITY_MAX', 'bool_reader', '255', 255, 'kernel/x86_64/media/vp8_constants.inc', 57), ('vp8', 'VP8_BOOL_LITERAL_BITS_MAX', 'bool_reader', '32', 32, 'kernel/x86_64/media/vp8_constants.inc', 58), ('vp8', 'VP8_BOOL_READER_BUF', 'bool_reader_layout', '0', 0, 'kernel/x86_64/media/vp8_constants.inc', 60), ('vp8', 'VP8_BOOL_READER_LEN', 'bool_reader_layout', '8', 8, 'kernel/x86_64/media/vp8_constants.inc', 61), ('vp8', 'VP8_BOOL_READER_INPUT_INDEX', 'bool_reader_layout', '12', 12, 'kernel/x86_64/media/vp8_constants.inc', 62), ('vp8', 'VP8_BOOL_READER_RANGE', 'bool_reader_layout', '16', 16, 'kernel/x86_64/media/vp8_constants.inc', 63), ('vp8', 'VP8_BOOL_READER_VALUE', 'bool_reader_layout', '20', 20, 'kernel/x86_64/media/vp8_constants.inc', 64), ('vp8', 'VP8_BOOL_READER_BIT_COUNT', 'bool_reader_layout', '24', 24, 'kernel/x86_64/media/vp8_constants.inc', 65), ('vp8', 'VP8_BOOL_READER_SIZE', 'bool_reader_layout', '32', 32, 'kernel/x86_64/media/vp8_constants.inc', 66),
  ('vp8', 'VP8_TOKEN_PARTITION_COUNT_MAX', 'token_partition', '8', 8, 'kernel/x86_64/media/vp8_constants.inc', 68), ('vp8', 'VP8_TOKEN_PARTITION_SIZE_BYTES', 'token_partition', '3', 3, 'kernel/x86_64/media/vp8_constants.inc', 69), ('vp8', 'VP8_TOKEN_PARTITIONS_COUNT', 'token_partition_layout', '0', 0, 'kernel/x86_64/media/vp8_constants.inc', 71), ('vp8', 'VP8_TOKEN_PARTITIONS_TABLE', 'token_partition_layout', '4', 4, 'kernel/x86_64/media/vp8_constants.inc', 72), ('vp8', 'VP8_TOKEN_PARTITION_ENTRY_SIZE', 'token_partition_layout', '8', 8, 'kernel/x86_64/media/vp8_constants.inc', 73), ('vp8', 'VP8_TOKEN_PARTITION_OFFSET', 'token_partition_layout', '0', 0, 'kernel/x86_64/media/vp8_constants.inc', 74), ('vp8', 'VP8_TOKEN_PARTITION_LEN', 'token_partition_layout', '4', 4, 'kernel/x86_64/media/vp8_constants.inc', 75),
  ('vp8', 'VP8_QUANT_BASE_BITS', 'quant', '7', 7, 'kernel/x86_64/media/vp8_constants.inc', 78), ('vp8', 'VP8_QUANT_DELTA_BITS', 'quant', '4', 4, 'kernel/x86_64/media/vp8_constants.inc', 79), ('vp8', 'VP8_QUANT_INDEX_MAX', 'quant', '127', 127, 'kernel/x86_64/media/vp8_constants.inc', 80), ('vp8', 'VP8_SEGMENT_COUNT', 'segmentation', '4', 4, 'kernel/x86_64/media/vp8_constants.inc', 101), ('vp8', 'VP8_SEGMENT_PROB_COUNT', 'segmentation', '3', 3, 'kernel/x86_64/media/vp8_constants.inc', 102), ('vp8', 'VP8_SEGMENT_PROB_DEFAULT', 'segmentation', '255', 255, 'kernel/x86_64/media/vp8_constants.inc', 103), ('vp8', 'VP8_LOOP_FILTER_LEVEL_BITS', 'loop_filter', '6', 6, 'kernel/x86_64/media/vp8_constants.inc', 115), ('vp8', 'VP8_LOOP_FILTER_SHARPNESS_BITS', 'loop_filter', '3', 3, 'kernel/x86_64/media/vp8_constants.inc', 116), ('vp8', 'VP8_LOOP_FILTER_LEVEL_MAX', 'loop_filter', '63', 63, 'kernel/x86_64/media/vp8_constants.inc', 129),
  ('vp8', 'VP8_LUMA_MODE_DC', 'prediction_mode', '0', 0, 'kernel/x86_64/media/vp8_constants.inc', 177), ('vp8', 'VP8_LUMA_MODE_VERTICAL', 'prediction_mode', '1', 1, 'kernel/x86_64/media/vp8_constants.inc', 178), ('vp8', 'VP8_LUMA_MODE_HORIZONTAL', 'prediction_mode', '2', 2, 'kernel/x86_64/media/vp8_constants.inc', 179), ('vp8', 'VP8_LUMA_MODE_TRUE_MOTION', 'prediction_mode', '3', 3, 'kernel/x86_64/media/vp8_constants.inc', 180), ('vp8', 'VP8_LUMA_MODE_B_PRED', 'prediction_mode', '4', 4, 'kernel/x86_64/media/vp8_constants.inc', 181), ('vp8', 'VP8_CHROMA_MODE_DC', 'prediction_mode', '0', 0, 'kernel/x86_64/media/vp8_constants.inc', 183), ('vp8', 'VP8_CHROMA_MODE_VERTICAL', 'prediction_mode', '1', 1, 'kernel/x86_64/media/vp8_constants.inc', 184), ('vp8', 'VP8_CHROMA_MODE_HORIZONTAL', 'prediction_mode', '2', 2, 'kernel/x86_64/media/vp8_constants.inc', 185), ('vp8', 'VP8_CHROMA_MODE_TRUE_MOTION', 'prediction_mode', '3', 3, 'kernel/x86_64/media/vp8_constants.inc', 186), ('vp8', 'VP8_INTRA4_MODE_COUNT', 'prediction_mode', '10', 10, 'kernel/x86_64/media/vp8_constants.inc', 206),
  ('vp8', 'VP8_COEFF_TYPE_COUNT', 'coefficient', '4', 4, 'kernel/x86_64/media/vp8_constants.inc', 230), ('vp8', 'VP8_COEFF_BAND_COUNT', 'coefficient', '8', 8, 'kernel/x86_64/media/vp8_constants.inc', 231), ('vp8', 'VP8_COEFF_CONTEXT_COUNT', 'coefficient', '3', 3, 'kernel/x86_64/media/vp8_constants.inc', 232), ('vp8', 'VP8_COEFF_PROBABILITY_COUNT', 'coefficient', '11', 11, 'kernel/x86_64/media/vp8_constants.inc', 233), ('vp8', 'VP8_COEFF_BLOCK_COEFF_COUNT', 'coefficient', '16', 16, 'kernel/x86_64/media/vp8_constants.inc', 248), ('vp8', 'VP8_IDCT_COSPI8SQRT2MINUS1', 'transform', '20091', 20091, 'kernel/x86_64/media/vp8_constants.inc', 253), ('vp8', 'VP8_IDCT_SINPI8SQRT2', 'transform', '35468', 35468, 'kernel/x86_64/media/vp8_constants.inc', 254),
  ('vp8', 'VP8_MACROBLOCK_SIZE', 'macroblock', '16', 16, 'kernel/x86_64/media/vp8_constants.inc', 263), ('vp8', 'VP8_BLOCK_SIZE', 'macroblock', '4', 4, 'kernel/x86_64/media/vp8_constants.inc', 264), ('vp8', 'VP8_CHROMA_BLOCK_SIZE', 'macroblock', '8', 8, 'kernel/x86_64/media/vp8_constants.inc', 265), ('vp8', 'VP8_Y_BLOCK_COUNT', 'macroblock', '16', 16, 'kernel/x86_64/media/vp8_constants.inc', 266), ('vp8', 'VP8_UV_BLOCK_COUNT', 'macroblock', '4', 4, 'kernel/x86_64/media/vp8_constants.inc', 267), ('vp8', 'VP8_MACROBLOCK_COEFF_BLOCK_COUNT', 'macroblock', '25', 25, 'kernel/x86_64/media/vp8_constants.inc', 269), ('vp8', 'VP8_NEUTRAL_LUMA', 'pixel', '128', 128, 'kernel/x86_64/media/vp8_constants.inc', 289), ('vp8', 'VP8_MAX_LEGACY_DIMENSION', 'dimension', '16384', 16384, 'kernel/x86_64/media/vp8_constants.inc', 292), ('vp8', 'VP8_YUV_CENTER', 'color', '128', 128, 'kernel/x86_64/media/vp8_constants.inc', 298), ('vp8', 'VP8_YUV_SHIFT', 'color', '8', 8, 'kernel/x86_64/media/vp8_constants.inc', 300), ('vp8', 'VP8_YUV_V_TO_R', 'color', '359', 359, 'kernel/x86_64/media/vp8_constants.inc', 301), ('vp8', 'VP8_YUV_U_TO_G', 'color', '88', 88, 'kernel/x86_64/media/vp8_constants.inc', 302), ('vp8', 'VP8_YUV_V_TO_G', 'color', '183', 183, 'kernel/x86_64/media/vp8_constants.inc', 303), ('vp8', 'VP8_YUV_U_TO_B', 'color', '454', 454, 'kernel/x86_64/media/vp8_constants.inc', 304), ('vp8', 'VP8_RGBA_ALPHA_OPAQUE', 'color', '255', 255, 'kernel/x86_64/media/vp8_constants.inc', 305),
  ('vp8', 'VP8_MV_COMPONENT_COUNT', 'motion_vector', '2', 2, 'kernel/x86_64/media/vp8_constants.inc', 320), ('vp8', 'VP8_MV_PROBABILITY_COUNT', 'motion_vector', '19', 19, 'kernel/x86_64/media/vp8_constants.inc', 321), ('vp8', 'VP8_MOTION_VECTOR_ROW', 'motion_vector_layout', '0', 0, 'kernel/x86_64/media/vp8_constants.inc', 333), ('vp8', 'VP8_MOTION_VECTOR_COL', 'motion_vector_layout', '2', 2, 'kernel/x86_64/media/vp8_constants.inc', 334), ('vp8', 'VP8_MOTION_VECTOR_SIZE', 'motion_vector_layout', '4', 4, 'kernel/x86_64/media/vp8_constants.inc', 335), ('vp8', 'VP8_SUBPIXEL_FILTER_TAP_COUNT', 'subpixel_filter', '6', 6, 'kernel/x86_64/media/vp8_constants.inc', 362), ('vp8', 'VP8_SUBPIXEL_FILTER_ROUND', 'subpixel_filter', '64', 64, 'kernel/x86_64/media/vp8_constants.inc', 363), ('vp8', 'VP8_SUBPIXEL_FILTER_SHIFT', 'subpixel_filter', '7', 7, 'kernel/x86_64/media/vp8_constants.inc', 364), ('vp8', 'VP8_SUBPIXEL_FILTER_PHASE_COUNT', 'subpixel_filter', '8', 8, 'kernel/x86_64/media/vp8_constants.inc', 365);

create table media_signature_fact (
  format_name text not null references media_format_fact(format_name),
  signature_kind text not null,
  byte_offset integer,
  byte_len integer not null,
  signature_hex text not null,
  signature_ascii text not null,
  primary key (format_name, signature_kind)
);

insert into media_signature_fact(format_name, signature_kind, byte_offset, byte_len, signature_hex, signature_ascii) values
  ('png', 'header', 0, 8, '89504e470d0a1a0a', ''), ('jpeg', 'header', 0, 2, 'ffd8', ''), ('jxl-codestream', 'header', 0, 2, 'ff0a', ''), ('jxl-container', 'header', 0, 12, '0000000c4a584c200d0a870a', ''), ('tga', 'footer', null, 18, '54525545564953494f4e2d5846494c452e00', 'TRUEVISION-XFILE.'), ('runtime-image', 'header', 0, 8, '4552494d47303031', 'ERIMG001'), ('ivf', 'header', 0, 4, '444b4946', 'DKIF'), ('webm-video', 'header', 0, 4, '1a45dfa3', ''), ('webm-audio', 'header', 0, 4, '1a45dfa3', '');

create table media_container_field_fact (
  format_name text not null references media_format_fact(format_name),
  field_name text not null,
  byte_offset integer not null,
  byte_len integer not null,
  endian text not null,
  value_kind text not null,
  required_value text not null,
  primary key (format_name, field_name)
);

insert into media_container_field_fact(format_name, field_name, byte_offset, byte_len, endian, value_kind, required_value) values
  ('png', 'ihdr.width', 16, 4, 'big', 'u32', ''), ('png', 'ihdr.height', 20, 4, 'big', 'u32', ''), ('png', 'ihdr.bit_depth', 24, 1, 'none', 'u8', '8'), ('png', 'ihdr.color_type', 25, 1, 'none', 'u8', '0|2|4|6'), ('png', 'ihdr.compression', 26, 1, 'none', 'u8', '0'), ('png', 'ihdr.filter', 27, 1, 'none', 'u8', '0'), ('png', 'ihdr.interlace', 28, 1, 'none', 'u8', '0'), ('runtime-image', 'abi_version', 8, 2, 'little', 'u16', '1'), ('runtime-image', 'format', 10, 2, 'little', 'u16', '1'), ('runtime-image', 'flags', 12, 4, 'little', 'u32', '0'), ('runtime-image', 'width', 16, 4, 'little', 'u32', ''), ('runtime-image', 'height', 20, 4, 'little', 'u32', ''), ('runtime-image', 'tile_w', 24, 2, 'little', 'u16', ''), ('runtime-image', 'tile_h', 26, 2, 'little', 'u16', ''), ('runtime-image', 'tile_count', 28, 4, 'little', 'u32', ''), ('runtime-image', 'payload_len', 32, 8, 'little', 'u64', ''), ('ivf', 'codec', 8, 4, 'none', 'ascii', 'VP80'), ('ivf', 'width', 12, 2, 'little', 'u16', ''), ('ivf', 'height', 14, 2, 'little', 'u16', ''), ('ivf', 'frame_count', 24, 4, 'little', 'u32', ''), ('tga', 'image_type', 2, 1, 'none', 'u8', '2'), ('tga', 'width', 12, 2, 'little', 'u16', ''), ('tga', 'height', 14, 2, 'little', 'u16', ''), ('tga', 'depth', 16, 1, 'none', 'u8', '24|32'), ('tga', 'descriptor', 17, 1, 'none', 'u8', '');

create table media_ebml_element_fact (
  format_name text not null references media_format_fact(format_name),
  element_name text not null,
  element_id_hex text not null,
  value_kind text not null,
  required_value text not null,
  primary key (format_name, element_name)
);

insert into media_ebml_element_fact(format_name, element_name, element_id_hex, value_kind, required_value) values
  ('webm-video', 'ebml', '1a45dfa3', 'master', ''), ('webm-video', 'segment', '18538067', 'master', ''), ('webm-video', 'tracks', '1654ae6b', 'master', ''), ('webm-video', 'track_entry', 'ae', 'master', ''), ('webm-video', 'track_type', '83', 'uint', '1'), ('webm-video', 'codec_id', '86', 'string', 'V_VP8'), ('webm-video', 'video', 'e0', 'master', ''), ('webm-video', 'pixel_width', 'b0', 'uint', ''), ('webm-video', 'pixel_height', 'ba', 'uint', ''), ('webm-video', 'cluster', '1f43b675', 'master', ''), ('webm-video', 'simple_block', 'a3', 'block', ''), ('webm-audio', 'ebml', '1a45dfa3', 'master', ''), ('webm-audio', 'segment', '18538067', 'master', ''), ('webm-audio', 'tracks', '1654ae6b', 'master', ''), ('webm-audio', 'track_entry', 'ae', 'master', ''), ('webm-audio', 'track_type', '83', 'uint', '2'), ('webm-audio', 'codec_id', '86', 'string', 'A_OPUS|A_VORBIS'), ('webm-audio', 'audio', 'e1', 'master', ''), ('webm-audio', 'sampling_frequency', 'b5', 'float', 'default:8000'), ('webm-audio', 'channels', '9f', 'uint', 'default:1'), ('webm-audio', 'cluster', '1f43b675', 'master', ''), ('webm-audio', 'simple_block', 'a3', 'block', '');

create view engine_entity_fact as
select 'category.' || category_name as entity_name,
       'category' as entity_kind,
       category_name,
       description as label,
       'engine.category' as provenance
from engine_category_fact
union all
select 'unit.' || unit_name,
       'unit',
       'unit',
       unit_name,
       'engine.unit'
from engine_unit_fact
union all
select 'relation.' || relation_name,
       'relation',
       'relation',
       relation_name,
       'engine.relation_kind'
from engine_relation_kind_fact
union all
select 'decision.' || decision_id,
       'decision',
       'decision',
       decision_name,
       source_name
from engine_tradeoff_decision_fact
union all
select 'option.' || option_id,
       'option',
       'option',
       option_name,
       'engine_tradeoff_option_fact'
from engine_tradeoff_option_fact
union all
select 'metric.' || metric_id,
       'metric',
       'metric',
       metric_name,
       'engine_tradeoff_metric_fact'
from engine_tradeoff_metric_fact
union all
select 'tradeoff.' || assessment_id,
       'tradeoff',
       'tradeoff',
       metric_id || ':' || cast(score as text),
       evidence
from engine_tradeoff_assessment_fact
union all
select 'tor.control',
       'control_surface',
       'control_surface',
       'tor-control',
       'tor_control_command_fact'
union all
select 'tor.control.command.' || command_name,
       command_kind,
       command_kind,
       command_name,
       'tor_control_command_fact'
from tor_control_command_fact
union all
select 'tor.control.event.' || event_name,
       'event',
       'event',
       event_name,
       'tor_control_event_fact'
from tor_control_event_fact
union all
select 'tor.control.reply.' || reply_code,
       'reply_code',
       'reply_code',
       cast(reply_code as text),
       'tor_control_reply_code_fact'
from tor_control_reply_code_fact
union all
select 'media.constant.' || codec_name || '.' || symbol_name,
       'constant',
       'constant',
       symbol_name,
       'media_codec_constant_fact'
from media_codec_constant_fact
union all
select 'protocol.' || id,
       'protocol',
       'protocol',
       name,
       'edgerun_protocol_fact'
from edgerun_protocol_fact
union all
select 'definition.' || id,
       case kind when 'sum-frame' then 'message' else 'message' end,
       'message',
       id,
       'edgerun_definition_fact'
from edgerun_definition_fact
union all
select 'field.' || definition.id || '.' || field.name,
       'field',
       'field',
       field.name,
       'edgerun_definition_field_fact'
from edgerun_definition_field_fact field
join edgerun_definition_fact definition using (definition_id)
union all
select 'clause.' || id,
       'clause',
       'clause',
       id,
       'edgerun_clause_fact'
from edgerun_clause_fact
union all
select 'standard.' || standard,
       'standard',
       'standard',
       standard,
       'edgerun_clause_fact'
from edgerun_clause_fact
group by standard
union all
select 'media.format.' || format_name,
       'media_format',
       'media_format',
       format_name,
       'media_format_fact'
from media_format_fact
union all
select 'media.codec.' || codec_name,
       'codec',
       'codec',
       codec_name,
       'media_codec_fact'
from media_codec_fact
union all
select 'media.field.' || format_name || '.' || field_name,
       'field',
       'field',
       field_name,
       'media_container_field_fact'
from media_container_field_fact
union all
select 'media.field.' || format_name || '.ebml.' || element_name,
       'field',
       'field',
       element_name,
       'media_ebml_element_fact'
from media_ebml_element_fact;

create view engine_relation_fact as
select 'category.' || child_category as subject_entity,
       relation_name,
       'category.' || parent_category as object_entity,
       null as object_value,
       '' as unit_name,
       'category_relation' as relation_source,
       'engine.category_relation' as provenance
from engine_category_relation_fact
union all
select 'unit.' || unit_name,
       'measured_in',
       'unit.' || base_unit_name,
       cast(scale_to_base as text),
       base_unit_name,
       'unit_conversion',
       'engine.unit'
from engine_unit_fact
union all
select 'decision.' || decision.decision_id,
       'has_option',
       'option.' || option.option_id,
       option.option_status,
       '',
       'tradeoff_option',
       'engine_tradeoff_option_fact'
from engine_tradeoff_decision_fact decision
join engine_tradeoff_option_fact option using (decision_id)
union all
select 'option.' || option_id,
       'has_tradeoff',
       'tradeoff.' || assessment_id,
       evidence,
       '',
       'tradeoff_assessment',
       'engine_tradeoff_assessment_fact'
from engine_tradeoff_assessment_fact
union all
select 'tradeoff.' || assessment_id,
       'uses_metric',
       'metric.' || metric_id,
       null,
       '',
       'tradeoff_metric',
       'engine_tradeoff_assessment_fact'
from engine_tradeoff_assessment_fact
union all
select 'tradeoff.' || assessment_id,
       'tradeoff_score',
       null,
       cast(score as text),
       '',
       'tradeoff_score',
       'engine_tradeoff_assessment_fact'
from engine_tradeoff_assessment_fact
union all
select 'tradeoff.' || assessment_id,
       'tradeoff_weight',
       null,
       cast(weight as text),
       '',
       'tradeoff_weight',
       'engine_tradeoff_assessment_fact'
from engine_tradeoff_assessment_fact
union all
select 'tor.control',
       'has_command',
       'tor.control.command.' || command_name,
       host_surface_status,
       '',
       'tor_control_command',
       'tor_control_command_fact'
from tor_control_command_fact
union all
select 'tor.control',
       'emits_event',
       'tor.control.event.' || event_name,
       host_surface_status,
       '',
       'tor_control_event',
       'tor_control_event_fact'
from tor_control_event_fact
union all
select 'tor.control',
       'has_reply_code',
       'tor.control.reply.' || reply_code,
       reply_class,
       '',
       'tor_control_reply_code',
       'tor_control_reply_code_fact'
from tor_control_reply_code_fact
union all
select 'protocol.' || protocol.id,
       'has_message',
       'definition.' || definition.id,
       null,
       '',
       'protocol_definition',
       'edgerun_definition_fact'
from edgerun_protocol_fact protocol
join edgerun_definition_fact definition on definition.id like protocol.id || '%'
union all
select 'definition.' || definition.id,
       'has_field',
       'field.' || definition.id || '.' || field.name,
       cast(field.field_order as text),
       '',
       'definition_field',
       'edgerun_definition_field_fact'
from edgerun_definition_field_fact field
join edgerun_definition_fact definition using (definition_id)
union all
select 'field.' || definition.id || '.' || field.name,
       'field_width',
       null,
       case field.field_type when 'u16be' then '16' else field.length_expr end,
       case field.field_type when 'u16be' then 'bit' else 'byte' end,
       'field_type_width',
       'edgerun_definition_field_fact'
from edgerun_definition_field_fact field
join edgerun_definition_fact definition using (definition_id)
union all
select 'field.' || definition_id || '.' || field_name,
       'field_offset',
       null,
       cast(byte_offset as text),
       'byte_offset',
       'field_layout',
       'engine_definition_field_layout_fact'
from engine_definition_field_layout_fact
union all
select 'clause.' || id,
       'constrains',
       'definition.' || subject,
       predicate_expr,
       '',
       'clause_subject',
       'edgerun_clause_fact'
from edgerun_clause_fact
union all
select 'clause.' || id,
       'defined_by',
       'standard.' || standard,
       section,
       '',
       'clause_standard',
       'edgerun_clause_fact'
from edgerun_clause_fact
union all
select 'media.format.' || format_name,
       'has_signature',
       null,
       signature_kind || ':' || signature_hex,
       'byte',
       'media_signature',
       'media_signature_fact'
from media_signature_fact
union all
select 'media.format.' || format_name,
       'supports_codec',
       'media.codec.' || codec_name,
       wire_id,
       '',
       'media_codec_binding',
       'media_format_codec_fact'
from media_format_codec_fact
union all
select 'media.codec.' || codec_name,
       'has_constant',
       'media.constant.' || codec_name || '.' || symbol_name,
       constant_group,
       '',
       'media_codec_constant',
       'media_codec_constant_fact'
from media_codec_constant_fact
union all
select 'media.constant.' || codec_name || '.' || symbol_name,
       'constant_value',
       null,
       cast(value_integer as text),
       '',
       'media_codec_constant',
       'media_codec_constant_fact'
from media_codec_constant_fact
union all
select 'media.format.' || format_name,
       'has_field',
       'media.field.' || format_name || '.' || field_name,
       required_value,
       '',
       'media_container_field',
       'media_container_field_fact'
from media_container_field_fact
union all
select 'media.field.' || format_name || '.' || field_name,
       'field_offset',
       null,
       cast(byte_offset as text),
       'byte_offset',
       'media_container_field',
       'media_container_field_fact'
from media_container_field_fact
union all
select 'media.field.' || format_name || '.' || field_name,
       'field_width',
       null,
       cast(byte_len * 8 as text),
       'bit',
       'media_container_field',
       'media_container_field_fact'
from media_container_field_fact
union all
select 'media.format.' || format_name,
       'has_field',
       'media.field.' || format_name || '.ebml.' || element_name,
       element_id_hex,
       '',
       'media_ebml_element',
       'media_ebml_element_fact'
from media_ebml_element_fact;

create view engine_relation_conflict as
select relation.subject_entity,
       relation.relation_name,
       relation.unit_name,
       count(distinct relation.object_value) as distinct_value_count,
       group_concat(distinct relation.object_value || ' ' || relation.unit_name) as values_seen
from engine_relation_resident relation
join engine_relation_kind_fact kind using (relation_name)
where kind.cardinality = 'single'
  and relation.object_value is not null
group by relation.subject_entity, relation.relation_name, relation.unit_name
having count(distinct relation.object_value) > 1;

create table engine_relation_signature_fact (
  relation_name text not null references engine_relation_kind_fact(relation_name),
  subject_category text not null references engine_category_fact(category_name),
  object_category text not null references engine_category_fact(category_name),
  unit_category text not null references engine_category_fact(category_name),
  primary key (relation_name, subject_category, object_category)
);

insert into engine_relation_signature_fact(relation_name, subject_category, object_category, unit_category) values
  ('field_offset', 'field', 'offset', 'unit'),
  ('field_width', 'field', 'width', 'unit');

create view engine_relation_import_gap as
select relation.subject_entity,
       relation.relation_name,
       relation.object_entity,
       relation.object_value,
       'unknown_relation_kind' as gap_kind,
       relation.provenance
from engine_relation_resident relation
left join engine_relation_kind_fact kind using (relation_name)
where kind.relation_name is null
union all
select relation.subject_entity,
       relation.relation_name,
       relation.object_entity,
       relation.object_value,
       'unknown_subject_entity',
       relation.provenance
from engine_relation_resident relation
left join engine_entity_resident entity on entity.entity_name = relation.subject_entity
where entity.entity_name is null
union all
select relation.subject_entity,
       relation.relation_name,
       relation.object_entity,
       relation.object_value,
       'unknown_object_entity',
       relation.provenance
from engine_relation_resident relation
left join engine_entity_resident entity on entity.entity_name = relation.object_entity
where relation.object_entity is not null
  and entity.entity_name is null;

create view engine_corpus_case_fact as
select derived.corpus_name,
       derived.case_name,
       replace(replace(trim(cast(hex_source.content as text)), char(10), ''), char(13), '') as hex_bytes,
       length(replace(replace(trim(cast(hex_source.content as text)), char(10), ''), char(13), '')) / 2 as byte_len,
       derived.description,
       derived.expect_exit
from toml_derived_corpus_case_fact derived
join edgerun_standards_source hex_source
  on hex_source.path like '%/standards/corpus/' || derived.corpus_name || '/' || derived.file_name;

create view engine_extracted_field_fact as
select corpus.case_name,
       corpus.corpus_name,
       layout.definition_id,
       layout.field_name,
       layout.field_type,
       binding.base_byte_offset + layout.byte_offset as byte_offset,
       layout.byte_len,
       case
         when length(corpus.hex_bytes) >= (binding.base_byte_offset + layout.byte_offset + layout.byte_len) * 2
          and layout.field_type = 'u16be' then
           ((instr('0123456789abcdef', lower(substr(corpus.hex_bytes, (binding.base_byte_offset + layout.byte_offset) * 2 + 1, 1))) - 1) << 12) |
           ((instr('0123456789abcdef', lower(substr(corpus.hex_bytes, (binding.base_byte_offset + layout.byte_offset) * 2 + 2, 1))) - 1) << 8) |
           ((instr('0123456789abcdef', lower(substr(corpus.hex_bytes, (binding.base_byte_offset + layout.byte_offset) * 2 + 3, 1))) - 1) << 4) |
           (instr('0123456789abcdef', lower(substr(corpus.hex_bytes, (binding.base_byte_offset + layout.byte_offset) * 2 + 4, 1))) - 1)
       end as integer_value
from engine_corpus_case_fact corpus
join engine_corpus_definition_binding_fact binding on binding.corpus_name = corpus.corpus_name
join engine_definition_field_layout_fact layout
  on layout.definition_id = binding.definition_id;

create view engine_case_value_fact as
select corpus.corpus_name,
       corpus.case_name,
       binding.definition_id,
       derivation.value_name,
       corpus.byte_len - binding.base_byte_offset + derivation.integer_add as integer_value
from engine_corpus_case_fact corpus
join engine_corpus_definition_binding_fact binding using (corpus_name)
join engine_case_value_derivation_fact derivation
  on derivation.definition_id = '*'
  or derivation.definition_id = binding.definition_id
union all
select corpus_name,
       case_name,
       definition_id,
       field_name,
       integer_value
from engine_extracted_field_fact
where integer_value is not null;

create view engine_clause_atom_result as
select expected.corpus_name,
       expected.case_name,
       clause.id as clause_name,
       atom.clause_id,
       atom.group_index,
       atom.atom_index,
       atom.lhs_name,
       atom.operator_name,
       value.integer_value,
       coalesce(rhs_value.integer_value + atom.rhs_integer_add, atom.rhs_integer) as rhs_integer_value,
       case atom.operator_name
         when '>=' then case when value.integer_value >= coalesce(rhs_value.integer_value + atom.rhs_integer_add, atom.rhs_integer) then 1 else 0 end
         when '==' then case when value.integer_value = coalesce(rhs_value.integer_value + atom.rhs_integer_add, atom.rhs_integer) then 1 else 0 end
         when '!=' then case when value.integer_value != coalesce(rhs_value.integer_value + atom.rhs_integer_add, atom.rhs_integer) then 1 else 0 end
         when 'in' then case when set_member.member_integer is not null then 1 else 0 end
         else 0
       end as atom_matches
from engine_corpus_expectation_fact expected
join edgerun_clause_fact clause on clause.id = expected.clause_name
join engine_clause_predicate_atom_fact atom using (clause_id)
join engine_predicate_operator_fact operator using (operator_name)
left join engine_case_value_resident value
  on value.corpus_name = expected.corpus_name
 and value.case_name = expected.case_name
 and value.definition_id = clause.subject
 and value.value_name = atom.lhs_name
left join engine_case_value_resident rhs_value
  on rhs_value.corpus_name = expected.corpus_name
 and rhs_value.case_name = expected.case_name
 and rhs_value.definition_id = clause.subject
 and rhs_value.value_name = atom.rhs_value_name
left join engine_clause_predicate_set_member_fact set_member
  on set_member.clause_id = atom.clause_id
 and set_member.group_index = atom.group_index
 and set_member.atom_index = atom.atom_index
 and set_member.member_integer = value.integer_value;

create view engine_clause_group_result as
select corpus_name,
       case_name,
       clause_name,
       clause_id,
       group_index,
       min(atom_matches) as group_matches
from engine_clause_atom_result
group by corpus_name, case_name, clause_name, clause_id, group_index;

create view engine_clause_result as
select corpus_name,
       case_name,
       clause_name,
       case when max(group_matches) = 1 then 'pass' else 'reject' end as actual_result
from engine_clause_group_result
group by corpus_name, case_name, clause_name;

create view engine_corpus_proof as
select expected.corpus_name,
       expected.case_name,
       expected.clause_name,
       expected.expected_result,
       result.actual_result,
       case when expected.expected_result = result.actual_result then 1 else 0 end as matches_expectation
from engine_corpus_expectation_fact expected
join engine_clause_result result
  on result.corpus_name = expected.corpus_name
 and result.case_name = expected.case_name
 and result.clause_name = expected.clause_name;

create table hpack_static_table_fact (
  hpack_index integer primary key,
  header_name text not null,
  header_value text not null
);

insert into hpack_static_table_fact(hpack_index, header_name, header_value) values
  (1, ':authority', ''), (2, ':method', 'GET'), (3, ':method', 'POST'), (4, ':path', '/'), (5, ':path', '/index.html'), (6, ':scheme', 'http'), (7, ':scheme', 'https'), (8, ':status', '200'), (9, ':status', '204'), (10, ':status', '206'), (11, ':status', '304'), (12, ':status', '400'), (13, ':status', '404'), (14, ':status', '500'), (15, 'accept-', ''), (16, 'accept-encoding', 'gzip, deflate'), (17, 'accept-language', ''), (18, 'accept-ranges', ''), (19, 'accept', ''), (20, 'access-control-allow-origin', ''), (21, 'age', ''), (22, 'allow', ''), (23, 'authorization', ''), (24, 'cache-control', ''), (25, 'content-disposition', ''), (26, 'content-encoding', ''), (27, 'content-language', ''), (28, 'content-length', ''), (29, 'content-location', ''), (30, 'content-range', ''), (31, 'content-type', ''), (32, 'cookie', ''), (33, 'date', ''), (34, 'etag', ''), (35, 'expect', ''), (36, 'expires', ''), (37, 'from', ''), (38, 'host', ''), (39, 'if-match', ''), (40, 'if-modified-since', ''), (41, 'if-none-match', ''), (42, 'if-range', ''), (43, 'if-unmodified-since', ''), (44, 'last-modified', ''), (45, 'link', ''), (46, 'location', ''), (47, 'max-forwards', ''), (48, 'proxy-authenticate', ''), (49, 'proxy-authorization', ''), (50, 'range', ''), (51, 'referer', ''), (52, 'refresh', ''), (53, 'retry-after', ''), (54, 'server', ''), (55, 'set-cookie', ''), (56, 'strict-transport-security', ''), (57, 'transfer-encoding', ''), (58, 'user-agent', ''), (59, 'vary', ''), (60, 'via', ''), (61, 'www-authenticate', '');

create table hpack_interop_case_fact (
  case_id integer primary key,
  fixture_name text not null,
  seqno integer not null,
  wire_hex text not null,
  header_count integer not null,
  unique (fixture_name, seqno)
);

insert into hpack_interop_case_fact(case_id, fixture_name, seqno, wire_hex, header_count)
select cast(json_each.key as integer) + 1,
       'nghttp2/basic',
       json_extract(json_each.value, '$.seqno'),
       json_extract(json_each.value, '$.wire'),
       json_array_length(json_extract(json_each.value, '$.headers'))
from edgerun_standards_source
join json_each(cast(edgerun_standards_source.content as text), '$.cases')
where edgerun_standards_source.namespace = 'hpack.fixture.nghttp2.basic';

create table quic_varint_rule_fact (
  rule_id integer primary key,
  min_value integer not null,
  max_value integer not null,
  byte_len integer not null,
  prefix_bits integer not null,
  prefix_hex text not null
);

insert into quic_varint_rule_fact(rule_id, min_value, max_value, byte_len, prefix_bits, prefix_hex) values
  (1, 0, 63, 1, 0, '00'),
  (2, 64, 16383, 2, 1, '40'),
  (3, 16384, 1073741823, 4, 2, '80'),
  (4, 1073741824, 4611686018427387903, 8, 3, 'c0');

create table quic_varint_example_fact (
  example_id integer primary key,
  value integer not null unique,
  expected_hex text not null
);

insert into quic_varint_example_fact(example_id, value, expected_hex) values
  (1, 42, '2a'),
  (2, 64, '4040'),
  (3, 16383, '7fff');

create view quic_varint_materialized_examples as
select example.value,
       case rule.byte_len
         when 1 then printf('%02x', example.value)
         when 2 then printf('%02x%02x', ((example.value >> 8) & 63) | 64, example.value & 255)
         when 4 then printf('%02x%02x%02x%02x', ((example.value >> 24) & 63) | 128, (example.value >> 16) & 255, (example.value >> 8) & 255, example.value & 255)
       end as actual_hex,
       example.expected_hex,
       case when example.expected_hex = case rule.byte_len
         when 1 then printf('%02x', example.value)
         when 2 then printf('%02x%02x', ((example.value >> 8) & 63) | 64, example.value & 255)
         when 4 then printf('%02x%02x%02x%02x', ((example.value >> 24) & 63) | 128, (example.value >> 16) & 255, (example.value >> 8) & 255, example.value & 255)
       end then 1 else 0 end as matches_expectation
from quic_varint_example_fact example
join quic_varint_rule_fact rule
  on example.value between rule.min_value and rule.max_value;

-- SQL TOML subset parser. This intentionally supports the local standards TOML
-- subset first: scalar assignments, [table], [[array_table]], simple arrays,
-- inline tables, and multiline expectation arrays.
create table sql_toml_line (
  source_id integer not null references edgerun_standards_source(source_id),
  line_no integer not null,
  raw_text text not null,
  text text not null,
  line_kind text not null,
  primary key (source_id, line_no)
);

with recursive lines(source_id, line_no, rest, line) as (
  select source_id, 1, replace(cast(content as text), char(13), '') || char(10), ''
  from edgerun_standards_source
  where format = 'toml'
  union all
  select source_id,
         line_no + 1,
         substr(rest, instr(rest, char(10)) + 1),
         substr(rest, 1, instr(rest, char(10)) - 1)
  from lines
  where rest <> '' and instr(rest, char(10)) > 0
)
insert into sql_toml_line(source_id, line_no, raw_text, text, line_kind)
select source_id,
       line_no - 1,
       line,
       trim(line),
       case
         when trim(line) = '' then 'blank'
         when substr(trim(line), 1, 1) = '#' then 'comment'
         when substr(trim(line), 1, 2) = '[[' and substr(trim(line), length(trim(line)) - 1, 2) = ']]' then 'array_table_header'
         when substr(trim(line), 1, 1) = '[' and substr(trim(line), length(trim(line)), 1) = ']' then 'table_header'
         when instr(trim(line), '=') > 0 then 'assignment'
         when trim(line) = ']' then 'array_end'
         when substr(trim(line), 1, 1) = '[' then 'array_item'
         else 'unknown'
       end
from lines
where line_no > 1;

create view sql_toml_scope_event as
select source_id,
       0 as line_no,
       'root' as scope_kind,
       '' as scope_path,
       1 as scope_instance
from edgerun_standards_source
where format = 'toml'
union all
select source_id,
       line_no,
       case line_kind when 'array_table_header' then 'array_table' else 'table' end,
       case line_kind
         when 'array_table_header' then substr(text, 3, length(text) - 4)
         else substr(text, 2, length(text) - 2)
       end as scope_path,
       case line_kind
         when 'array_table_header' then
           count(*) over (
             partition by source_id, substr(text, 3, length(text) - 4)
             order by line_no rows unbounded preceding
           )
         else 1
       end as scope_instance
from sql_toml_line
where line_kind in ('table_header', 'array_table_header');

create view sql_toml_scope_event_resident as select * from sql_toml_scope_event;

create view sql_toml_assignment as
with assignment_line as (
  select source_id,
         row_number() over (partition by source_id order by line_no) as assignment_id,
         line_no,
         text,
         raw_text
  from sql_toml_line
  where line_kind = 'assignment'
), scoped_line as (
  select line.source_id,
         line.assignment_id,
         line.line_no,
         line.text,
         line.raw_text,
         max(scope.line_no) as scope_line_no,
         max(parent.line_no) as parent_line_no
  from assignment_line line
  left join sql_toml_scope_event_resident scope
    on scope.source_id = line.source_id
   and scope.line_no < line.line_no
  left join sql_toml_scope_event_resident parent
    on parent.source_id = line.source_id
   and parent.scope_kind = 'array_table'
   and parent.line_no < line.line_no
  group by line.source_id, line.assignment_id, line.line_no, line.text, line.raw_text
)
select line.source_id,
       line.assignment_id,
       line.line_no,
       scope.scope_path,
       scope.scope_kind,
       scope.scope_instance,
       coalesce(parent.scope_path, '') as parent_array_path,
       coalesce(parent.scope_instance, 0) as parent_array_instance,
       trim(substr(line.text, 1, instr(line.text, '=') - 1)) as key,
       trim(substr(line.text, instr(line.text, '=') + 1)) as raw_value,
       line.raw_text
from scoped_line line
join sql_toml_scope_event_resident scope
  on scope.source_id = line.source_id
 and scope.line_no = line.scope_line_no
left join sql_toml_scope_event_resident parent
  on parent.source_id = line.source_id
 and parent.line_no = line.parent_line_no;

create view sql_toml_value as
select source_id,
       assignment_id,
       line_no,
       scope_path,
       scope_kind,
       scope_instance,
       parent_array_path,
       parent_array_instance,
       key,
       raw_value,
       case
         when raw_value glob '"*"' then 'string'
         when raw_value = 'true' or raw_value = 'false' then 'bool'
         when raw_value glob '-[0-9]*' or raw_value glob '[0-9]*' then 'integer'
         when raw_value = '[' or raw_value glob '\[*\]' then 'array'
         when raw_value glob '{*}' then 'inline_table'
         else 'unknown'
       end as value_kind,
       case when raw_value glob '"*"' then substr(raw_value, 2, length(raw_value) - 2) end as string_value,
       case when raw_value glob '-[0-9]*' or raw_value glob '[0-9]*' then cast(raw_value as integer) end as int_value,
       case when raw_value = 'true' then 1 when raw_value = 'false' then 0 end as bool_value
from sql_toml_assignment;

create view sql_toml_multiline_array_pair_item as
select assignment.source_id,
       assignment.assignment_id,
       assignment.scope_path,
       assignment.scope_instance,
       assignment.parent_array_path,
       assignment.parent_array_instance,
       assignment.key,
       item.line_no,
       row_number() over (partition by assignment.source_id, assignment.assignment_id order by item.line_no) as item_index,
       substr(trim(item.text), 3, instr(substr(trim(item.text), 3), '"') - 1) as first_value,
       substr(
         substr(trim(item.text), instr(trim(item.text), ',') + 1),
         instr(substr(trim(item.text), instr(trim(item.text), ',') + 1), '"') + 1,
         instr(substr(substr(trim(item.text), instr(trim(item.text), ',') + 1), instr(substr(trim(item.text), instr(trim(item.text), ',') + 1), '"') + 1), '"') - 1
       ) as second_value
from sql_toml_assignment_resident assignment
join sql_toml_line item
  on item.source_id = assignment.source_id
 and item.line_no > assignment.line_no
 and item.line_no < coalesce((select min(end_line.line_no)
                              from sql_toml_line end_line
                              where end_line.source_id = assignment.source_id
                                and end_line.line_no > assignment.line_no
                                and end_line.line_kind = 'array_end'), assignment.line_no)
where assignment.raw_value = '['
    and substr(trim(item.text), 1, 2) = '["';

create view sql_toml_inline_field as
select source_id,
       assignment_id,
       key as inline_table_key,
       substr(raw_value, 2, length(raw_value) - 2) as inline_table_body
from sql_toml_value_resident
where value_kind = 'inline_table';

create view sql_toml_parse_gap as
select source.namespace,
       line.line_no,
       'unknown_line' as gap_kind,
       line.raw_text
from sql_toml_line line
join edgerun_standards_source source using (source_id)
where line.line_kind = 'unknown'
union all
select source.namespace,
       value.line_no,
       'unknown_value',
       value.raw_value
from sql_toml_value_resident value
join edgerun_standards_source source using (source_id)
where value.value_kind = 'unknown';

create view sql_toml_assignment_resident as select * from sql_toml_assignment;
create view sql_toml_value_resident as select * from sql_toml_value;
create view sql_toml_pair_resident as select * from sql_toml_multiline_array_pair_item;

create view toml_derived_definition_fact as
select source.source_id,
       max(case when value.scope_path = '' and value.key = 'id' then value.string_value end) as id,
       max(case when value.scope_path = '' and value.key = 'kind' then value.string_value end) as kind,
       max(case when value.scope_path = '' and value.key = 'standard' then value.string_value end) as standard,
       max(case when value.scope_path = '' and value.key = 'section' then value.string_value end) as section
from edgerun_standards_source source
join sql_toml_value_resident value using (source_id)
where source.path like '%/standards/definitions/%.toml'
group by source.source_id;

create view toml_derived_definition_field_fact as
select definition.id as definition_id,
       value.scope_instance as field_order,
       max(case when value.key = 'name' then value.string_value end) as name,
       max(case when value.key = 'type' then value.string_value end) as field_type,
       coalesce(max(case when value.key = 'length' then value.string_value end), '') as length_expr,
       coalesce(max(case when value.key = 'constraint' then value.string_value end), '') as constraint_expr
from sql_toml_value_resident value
join toml_derived_definition_fact definition using (source_id)
where value.scope_path = 'field'
group by definition.id, value.scope_instance;

create view toml_derived_definition_variant_fact as
select definition.id as definition_id,
       max(case when value.key = 'name' then value.string_value end) as variant_name,
       max(case when value.key = 'tag_field' then value.string_value end) as tag_field,
       max(case when value.key = 'tag' then value.int_value end) as tag_value
from sql_toml_value_resident value
join toml_derived_definition_fact definition using (source_id)
where value.scope_path = 'variant'
group by definition.id, value.scope_instance;

create view toml_derived_clause_fact as
select source.source_id,
       case when clause.scope_path = 'clause' then clause.scope_instance else clause.parent_array_instance end as scope_instance,
       max(case when clause.scope_path = 'clause' and clause.key = 'id' then clause.string_value end) as id,
       max(case when clause.scope_path = 'clause' and clause.key = 'standard' then clause.string_value end) as standard,
       max(case when clause.scope_path = 'clause' and clause.key = 'section' then clause.string_value end) as section,
       max(case when clause.scope_path = 'clause' and clause.key = 'keyword' then clause.string_value end) as keyword,
       max(case when clause.scope_path = 'clause' and clause.key = 'subject' then clause.string_value end) as subject,
       max(case when clause.scope_path = 'clause.predicate' and clause.key = 'expr' then clause.string_value end) as predicate_expr,
       max(case when clause.scope_path = 'clause.on_violation' and clause.key = 'code' then clause.string_value end) as violation_code,
       max(case when clause.scope_path = 'clause.on_violation' and clause.key = 'message' then clause.string_value end) as violation_message
from edgerun_standards_source source
join sql_toml_value_resident clause on clause.source_id = source.source_id
where source.path like '%/standards/clauses/%.toml'
  and (clause.scope_path = 'clause' or clause.parent_array_path = 'clause')
group by source.source_id, case when clause.scope_path = 'clause' then clause.scope_instance else clause.parent_array_instance end;

create view toml_derived_corpus_case_fact as
select source.source_id,
       substr(substr(source.path, length('/home/ken/edgerun/standards/corpus/') + 1), 1, instr(substr(source.path, length('/home/ken/edgerun/standards/corpus/') + 1), '/') - 1) as corpus_name,
       value.scope_instance as case_instance,
       max(case when value.key = 'id' then value.string_value end) as case_name,
       max(case when value.key = 'file' then value.string_value end) as file_name,
       max(case when value.key = 'description' then value.string_value end) as description,
       max(case when value.key = 'expect_exit' then value.int_value end) as expect_exit
from edgerun_standards_source source
join sql_toml_value_resident value using (source_id)
where source.path like '%/standards/corpus/%/cases.toml'
  and value.scope_path = 'case'
group by source.source_id, value.scope_instance;

create view standards_fact_rule as
select 1 as rule_id,
       'observe_toml_line' as rule_name,
       'source_bytes' as input_fact_kind,
       'source_line_observation' as output_fact_kind,
       'Split imported source bytes into deterministic line observations.' as description
union all
select 2, 'classify_toml_line_shape', 'source_line_observation', 'line_shape_classification', 'Classify observed source lines by explicit byte/character facts.'
union all
select 3, 'classify_toml_scalar_value', 'assignment_observation', 'typed_value_fact', 'Classify observed assignment values by explicit value-shape facts.'
union all
select 4, 'derive_corpus_case_fact', 'typed_value_fact', 'corpus_case_fact', 'Derive corpus case facts from classified case-scope values.'
union all
select 5, 'derive_corpus_expectation_fact', 'array_pair_observation', 'corpus_expectation_fact', 'Derive corpus expectation facts from classified expectation pair observations.';

create view standards_observed_fact as
select 'source:' || source_id as fact_id,
       'source_bytes' as fact_kind,
       namespace as subject,
       'format' as predicate,
       format as object,
       namespace,
       0 as line_no,
       path as evidence
from edgerun_standards_source
union all
select 'line:' || source.namespace || ':' || line.line_no,
       'source_line_observation',
       source.namespace,
       'line_text',
       line.text,
       source.namespace,
       line.line_no,
       line.raw_text
from sql_toml_line line
join edgerun_standards_source source using (source_id)
union all
select 'line_shape:' || source.namespace || ':' || line.line_no,
       'line_shape_observation',
       source.namespace,
       'line_kind',
       line.line_kind,
       source.namespace,
       line.line_no,
       line.raw_text
from sql_toml_line line
join edgerun_standards_source source using (source_id)
union all
select 'assignment:' || source.namespace || ':' || value.assignment_id,
       'assignment_observation',
       source.namespace || ':' || value.scope_path || ':' || value.key,
       'raw_value',
       value.raw_value,
       source.namespace,
       value.line_no,
       value.raw_value
from sql_toml_value_resident value
join edgerun_standards_source source using (source_id)
union all
select 'array_pair:' || source.namespace || ':' || pair.assignment_id || ':' || pair.item_index,
       'array_pair_observation',
       source.namespace || ':' || pair.scope_path || ':' || pair.key,
       pair.first_value,
       pair.second_value,
       source.namespace,
       pair.line_no,
       pair.first_value || '=' || pair.second_value
from sql_toml_pair_resident pair
join edgerun_standards_source source using (source_id);

create view standards_observed_resident as select * from standards_observed_fact;

create view standards_fact_rule_application as
select 'apply:observe_line:' || source.namespace || ':' || line.line_no as application_id,
       rule.rule_id,
       rule.rule_name,
       'source:' || line.source_id as input_fact_id,
       'line:' || source.namespace || ':' || line.line_no as output_fact_id,
       source.namespace,
       line.line_no,
       'derived' as status
from sql_toml_line line
join edgerun_standards_source source using (source_id)
join standards_fact_rule rule on rule.rule_name = 'observe_toml_line'
union all
select 'apply:classify_line:' || source.namespace || ':' || line.line_no,
       rule.rule_id,
       rule.rule_name,
       'line:' || source.namespace || ':' || line.line_no,
       'line_shape:' || source.namespace || ':' || line.line_no,
       source.namespace,
       line.line_no,
       case when line.line_kind = 'unknown' then 'gap' else 'derived' end
from sql_toml_line line
join edgerun_standards_source source using (source_id)
join standards_fact_rule rule on rule.rule_name = 'classify_toml_line_shape'
union all
select 'apply:classify_value:' || source.namespace || ':' || value.assignment_id,
       rule.rule_id,
       rule.rule_name,
       'assignment:' || source.namespace || ':' || value.assignment_id,
       'typed_value:' || source.namespace || ':' || value.assignment_id,
       source.namespace,
       value.line_no,
       case when value.value_kind = 'unknown' then 'gap' else 'derived' end
from sql_toml_value_resident value
join edgerun_standards_source source using (source_id)
join standards_fact_rule rule on rule.rule_name = 'classify_toml_scalar_value'
union all
select 'apply:derive_case:' || case_fact.corpus_name || ':' || case_fact.case_name,
       rule.rule_id,
       rule.rule_name,
       'typed_value:' || source.namespace || ':' || case_fact.case_instance,
       'corpus_case:' || case_fact.corpus_name || ':' || case_fact.case_name,
       source.namespace,
       0,
       'derived'
from toml_derived_corpus_case_fact case_fact
join edgerun_standards_source source using (source_id)
join standards_fact_rule rule on rule.rule_name = 'derive_corpus_case_fact'
where case_fact.case_name is not null
union all
select 'apply:derive_expectation:' || case_fact.corpus_name || ':' || case_fact.case_name || ':' || pair.first_value,
       rule.rule_id,
       rule.rule_name,
       'array_pair:' || source.namespace || ':' || pair.assignment_id || ':' || pair.item_index,
       'corpus_expectation:' || case_fact.corpus_name || ':' || case_fact.case_name || ':' || pair.first_value,
       source.namespace,
       pair.line_no,
       'derived'
from toml_derived_corpus_case_fact case_fact
join sql_toml_pair_resident pair
  on pair.source_id = case_fact.source_id
 and pair.scope_path = 'case'
 and pair.scope_instance = case_fact.case_instance
 and pair.key = 'expect'
join edgerun_standards_source source on source.source_id = case_fact.source_id
join standards_fact_rule rule on rule.rule_name = 'derive_corpus_expectation_fact';

create view standards_fact_rule_application_resident as select * from standards_fact_rule_application;

create view standards_derived_fact as
select 'corpus_case:' || case_fact.corpus_name || ':' || case_fact.case_name as fact_id,
       rule.output_fact_kind as fact_kind,
       case_fact.corpus_name as subject,
       case_fact.case_name as predicate,
       case_fact.file_name as object,
       rule.rule_name,
       'typed_value:' || source.namespace || ':' || case_fact.case_instance as input_fact_id,
       source.namespace,
       0 as line_no
from toml_derived_corpus_case_fact case_fact
join edgerun_standards_source source using (source_id)
join standards_fact_rule rule on rule.rule_name = 'derive_corpus_case_fact'
where case_fact.case_name is not null
union all
select 'corpus_expectation:' || case_fact.corpus_name || ':' || case_fact.case_name || ':' || pair.first_value,
       rule.output_fact_kind,
       case_fact.corpus_name,
       case_fact.case_name || ':' || pair.first_value,
       pair.second_value,
       rule.rule_name,
       'array_pair:' || source.namespace || ':' || pair.assignment_id || ':' || pair.item_index,
       source.namespace,
       pair.line_no
from toml_derived_corpus_case_fact case_fact
join sql_toml_pair_resident pair
  on pair.source_id = case_fact.source_id
 and pair.scope_path = 'case'
 and pair.scope_instance = case_fact.case_instance
 and pair.key = 'expect'
join edgerun_standards_source source on source.source_id = case_fact.source_id
join standards_fact_rule rule on rule.rule_name = 'derive_corpus_expectation_fact';

create view standards_derived_resident as select * from standards_derived_fact;

create view standards_fact_gap as
select application.rule_name as gap_kind,
       application.namespace,
       application.line_no,
       observed.evidence
from standards_fact_rule_application_resident application
left join standards_observed_resident observed on observed.fact_id = application.input_fact_id
where application.status = 'gap';

create view toml_derived_corpus_expectation_fact as
select subject as corpus_name,
       substr(predicate, 1, instr(predicate, ':') - 1) as case_name,
       substr(predicate, instr(predicate, ':') + 1) as clause_name,
       object as expected_result
from standards_derived_resident
where fact_kind = 'corpus_expectation_fact';

create view engine_corpus_expectation_fact as select * from toml_derived_corpus_expectation_fact;

create view engine_case_value_resident as select * from engine_case_value_fact;

create index edgerun_clause_id_idx on edgerun_clause_fact(id);
create index edgerun_clause_subject_idx on edgerun_clause_fact(subject);
create index edgerun_standards_source_format_idx on edgerun_standards_source(format);
create index edgerun_standards_source_path_idx on edgerun_standards_source(path);
create index sql_toml_line_kind_idx on sql_toml_line(source_id, line_kind, line_no);
create index sql_toml_line_no_idx on sql_toml_line(source_id, line_no);

create view engine_entity_resident as select * from engine_entity_fact;
create view engine_relation_resident as select * from engine_relation_fact;

-- Canonical fact engine view layer. Domain importers only emit observations;
-- rules classify, derive, validate, and materialize facts with explicit
-- derivation records and queryable gaps.
create view engine_rule as
select 'standards:' || rule_name as rule_key,
       rule_name,
       case
         when rule_name like 'observe_%' then 'observe'
         when rule_name like 'classify_%' then 'classify'
         when rule_name like 'derive_%' then 'derive'
         else 'derive'
       end as rule_kind,
       input_fact_kind,
       output_fact_kind,
       description
from standards_fact_rule
union all
select 'standards:validate_corpus_expectation',
       'validate_corpus_expectation',
       'validate',
       'corpus_expectation_fact',
       'corpus_proof_fact',
       'Validate derived corpus expectations against executable clause results.';

create view engine_rule_io as
select rule_key,
       'input' as io_kind,
       1 as sequence,
       input_fact_kind as fact_kind
from engine_rule
union all
select rule_key,
       'output',
       1,
       output_fact_kind
from engine_rule;

create view engine_fact as
select fact_id,
       fact_kind,
       subject,
       predicate,
       object,
       'text' as value_type,
       'observed' as fact_status,
       namespace,
       line_no,
       evidence,
       'observed:' || fact_id || ':' || length(coalesce(object, '')) as stable_key
from standards_observed_resident
union all
select fact_id,
       fact_kind,
       subject,
       predicate,
       object,
       'text',
       'derived',
       namespace,
       line_no,
       input_fact_id,
       'derived:' || fact_id || ':' || rule_name || ':' || length(coalesce(object, ''))
from standards_derived_resident
union all
select 'entity:' || entity_name,
       'entity_fact',
       entity_name,
       'category',
       category_name,
       'text',
       'derived',
       'engine.entity',
       0,
       provenance,
       'entity:' || entity_name || ':' || category_name
from engine_entity_resident
union all
select 'relation:' || subject_entity || ':' || relation_name || ':' || coalesce(object_entity, object_value, ''),
       'relation_fact',
       subject_entity,
       relation_name,
       coalesce(object_entity, object_value || case when unit_name <> '' then ' ' || unit_name else '' end),
       'text',
       'derived',
       'engine.relation',
       0,
       provenance,
       'relation:' || subject_entity || ':' || relation_name || ':' || coalesce(object_entity, object_value, '') || ':' || unit_name
from engine_relation_resident
union all
select 'tradeoff.decision:' || decision_id,
       'tradeoff_decision_fact',
       decision_id,
       decision_name,
       decision_goal,
       'text',
       'observed',
       'engine.tradeoff',
       0,
       source_name,
       'tradeoff.decision:' || decision_id || ':' || decision_goal
from engine_tradeoff_decision_fact
union all
select 'tradeoff.option:' || option_id,
       'tradeoff_option_fact',
       decision_id,
       option_id,
       option_status || ':' || option_summary,
       'text',
       'observed',
       'engine.tradeoff',
       0,
       'engine_tradeoff_option_fact',
       'tradeoff.option:' || option_id || ':' || option_status
from engine_tradeoff_option_fact
union all
select 'tradeoff.assessment:' || assessment_id,
       'tradeoff_assessment_fact',
       option_id,
       metric_id,
       cast(score as text) || ':' || cast(weight as text) || ':' || evidence,
       'text',
       'observed',
       'engine.tradeoff',
       0,
       'engine_tradeoff_assessment_fact',
       'tradeoff.assessment:' || assessment_id || ':' || cast(score as text) || ':' || cast(weight as text)
from engine_tradeoff_assessment_fact
union all
select 'tor.control.command:' || command_name,
       'tor_control_command_fact',
       'tor.control',
       command_name,
       command_kind || ':' || host_surface_status,
       'text',
       'observed',
       'tor.control',
       source_line,
       source_name,
       'tor.control.command:' || command_name || ':' || command_kind || ':' || host_surface_status
from tor_control_command_fact
union all
select 'tor.control.event:' || event_name,
       'tor_control_event_fact',
       'tor.control',
       event_name,
       event_area || ':' || host_surface_status,
       'text',
       'observed',
       'tor.control',
       source_line,
       source_name,
       'tor.control.event:' || event_name || ':' || event_area || ':' || host_surface_status
from tor_control_event_fact
union all
select 'tor.control.reply:' || reply_code,
       'tor_control_reply_code_fact',
       'tor.control',
       cast(reply_code as text),
       reply_class || ':' || meaning,
       'text',
       'observed',
       'tor.control',
       source_line,
       source_name,
       'tor.control.reply:' || reply_code || ':' || reply_class
from tor_control_reply_code_fact
union all
select 'tor.control.signal:' || signal_name,
       'tor_control_signal_fact',
       'tor.control',
       signal_name,
       effect_summary || case when posix_alias <> '' then ':posix=' || posix_alias else '' end,
       'text',
       'observed',
       'tor.control',
       source_line,
       source_name,
       'tor.control.signal:' || signal_name || ':' || host_surface_status
from tor_control_signal_fact
union all
select 'tor.control.getinfo:' || key_pattern,
       'tor_control_getinfo_key_fact',
       'tor.control',
       key_pattern,
       key_group || ':' || value_kind || ':' || host_surface_status,
       'text',
       'observed',
       'tor.control',
       source_line,
       source_name,
       'tor.control.getinfo:' || key_pattern || ':' || key_group
from tor_control_getinfo_key_fact
union all
select 'tor.control.bootstrap:' || tag,
       'tor_control_bootstrap_phase_fact',
       'tor.control',
       tag,
       cast(progress as text) || ':stage=' || cast(stage as text) || ':' || summary,
       'text',
       'observed',
       'tor.control',
       source_line,
       source_name,
       'tor.control.bootstrap:' || cast(progress as text) || ':' || tag
from tor_control_bootstrap_phase_fact
union all
select 'tor.control.status_action:' || status_type || ':' || action_name,
       'tor_control_status_action_fact',
       status_type,
       action_name,
       severity_set || ':' || argument_set,
       'text',
       'observed',
       'tor.control',
       source_line,
       source_name,
       'tor.control.status_action:' || status_type || ':' || action_name
from tor_control_status_action_fact
union all
select 'tor.bandwidth.version:' || format_version,
       'tor_bandwidth_file_version_fact',
       'tor.bandwidth_file',
       format_version,
       status || ':' || semantic_delta,
       'text',
       'observed',
       'tor.bandwidth_file',
       source_line,
       source_name,
       'tor.bandwidth.version:' || format_version || ':' || status
from tor_bandwidth_file_version_fact
union all
select 'tor.bandwidth.grammar:' || grammar_name,
       'tor_bandwidth_file_grammar_fact',
       'tor.bandwidth_file',
       grammar_name,
       expression,
       'text',
       'observed',
       'tor.bandwidth_file',
       source_line,
       source_name,
       'tor.bandwidth.grammar:' || grammar_name || ':' || expression
from tor_bandwidth_file_grammar_fact
union all
select 'tor.bandwidth.key:' || section_name || ':' || key_name,
       'tor_bandwidth_file_key_fact',
       'tor.bandwidth_file.' || section_name,
       key_name,
       value_type || ':' || cardinality || ':' || introduced_version || ':' || removed_version || ':' || semantic_role,
       'text',
       'observed',
       'tor.bandwidth_file',
       source_line,
       source_name,
       'tor.bandwidth.key:' || section_name || ':' || key_name || ':' || introduced_version || ':' || removed_version
from tor_bandwidth_file_key_fact
union all
select 'tor.bandwidth.rule:' || rule_name,
       'tor_bandwidth_file_rule_fact',
       'tor.bandwidth_file',
       rule_name,
       rule_kind || ':' || rule_text,
       'text',
       'observed',
       'tor.bandwidth_file',
       source_line,
       source_name,
       'tor.bandwidth.rule:' || rule_name || ':' || rule_kind
from tor_bandwidth_file_rule_fact
union all
select 'media.constant:' || codec_name || ':' || symbol_name,
       'media_codec_constant_fact',
       'media.codec.' || codec_name,
       symbol_name,
       cast(value_integer as text),
       'integer',
       'observed',
       'media.codec.' || codec_name,
       source_line,
       source_name,
       'media.constant:' || codec_name || ':' || symbol_name || ':' || value_text
from media_codec_constant_fact
union all
select 'proof:' || corpus_name || ':' || case_name || ':' || clause_name,
       'corpus_proof_fact',
       corpus_name,
       case_name || ':' || clause_name,
       case when matches_expectation = 1 then 'pass' else 'fail' end,
       'text',
       case when matches_expectation = 1 then 'validated' else 'conflict' end,
       'standards.corpus.' || corpus_name || '.cases',
       0,
       'corpus_expectation:' || corpus_name || ':' || case_name || ':' || clause_name,
       'proof:' || corpus_name || ':' || case_name || ':' || clause_name || ':' || expected_result || ':' || actual_result
from engine_corpus_proof;

create view engine_fact_resident as select * from engine_fact;

create view engine_derivation as
select application.application_id as derivation_id,
       'standards:' || application.rule_name as rule_key,
       application.input_fact_id,
       application.output_fact_id,
       application.status,
       application.namespace,
       application.line_no,
       application.rule_name || ':' || application.input_fact_id || '->' || application.output_fact_id as stable_key
from standards_fact_rule_application_resident application
union all
select 'apply:validate_corpus:' || corpus_name || ':' || case_name || ':' || clause_name,
       'standards:validate_corpus_expectation',
       'corpus_expectation:' || corpus_name || ':' || case_name || ':' || clause_name,
       'proof:' || corpus_name || ':' || case_name || ':' || clause_name,
       case when matches_expectation = 1 then 'derived' else 'conflict' end,
       'standards.corpus.' || corpus_name || '.cases',
       0,
       'validate_corpus_expectation:' || corpus_name || ':' || case_name || ':' || clause_name || ':' || expected_result || ':' || actual_result
from engine_corpus_proof;

create view engine_derivation_resident as select * from engine_derivation;

create view engine_gap as
select 'standards:' || gap_kind as gap_kind,
       namespace,
       line_no,
       evidence,
       'classification_gap' as gap_class
from standards_fact_gap
union all
select 'standards:proof_mismatch',
       'standards.corpus.' || corpus_name || '.cases',
       0,
       corpus_name || ':' || case_name || ':' || clause_name || ':expected=' || expected_result || ':actual=' || actual_result,
       'validation_gap'
from engine_corpus_proof
where matches_expectation = 0
union all
select 'standards:' || gap_kind,
       'standards.clause.' || clause_name,
       0,
       atom_text,
       'predicate_parse_gap'
from engine_clause_predicate_parse_gap
union all
select 'engine:' || gap_kind,
       coalesce(subject_entity, ''),
       0,
       relation_name || ':' || coalesce(object_entity, object_value, '') || ':' || provenance,
       'relation_import_gap'
from engine_relation_import_gap;

create view engine_gap_resident as select * from engine_gap;

create view engine_conflict as
select fact_kind,
       subject,
       predicate,
       count(distinct object) as distinct_value_count,
       group_concat(distinct object) as values_seen
from engine_fact_resident
where fact_kind in ('corpus_case_fact', 'corpus_expectation_fact', 'corpus_proof_fact')
group by fact_kind, subject, predicate
having count(distinct object) > 1
union all
select 'relation_fact',
       subject_entity,
       relation_name,
       distinct_value_count,
       values_seen
from engine_relation_conflict;

create view engine_conflict_resident as select * from engine_conflict;

create view engine_closure_step_0 as
select * from engine_fact_resident where fact_status = 'observed';

create view engine_closure_step_1 as
select * from engine_fact_resident where fact_status = 'derived';

create view engine_closure_step_2 as
select * from engine_fact_resident where fact_status in ('validated', 'conflict');

create view engine_closure_final as
select * from engine_fact_resident
where fact_status in ('observed', 'derived', 'validated');

create view engine_summary as
select 'fact:' || fact_kind as item_kind,
       fact_status as status,
       count(*) as item_count
from engine_fact_resident
group by fact_kind, fact_status
union all
select 'derivation', status, count(*)
from engine_derivation_resident
group by status
union all
select 'gap:' || gap_kind, gap_class, count(*)
from engine_gap_resident
group by gap_kind, gap_class
union all
select 'conflict', fact_kind, count(*)
from engine_conflict_resident
group by fact_kind;

create view engine_corpus_proof_summary as
select corpus_name,
       min(matches_expectation) as all_expectations_match,
       count(*) as expectation_count
from engine_corpus_proof
group by corpus_name;
