-- EdgeRun canonical object catalog authoring view.
--
-- This SQL is not the runtime authority and must not become an external build
-- dependency. It is the compact, queryable editing/index form for finite code
-- vocabularies. The materialized authority remains the checked .erobj objects.

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
  (1, 'void', 0, 0, 0, 'kernel/x86_64/object/type/void.erobj'),
  (2, 'u1', 1, 1, 0, 'kernel/x86_64/object/type/u1.erobj'),
  (3, 'u8', 1, 8, 0, 'kernel/x86_64/object/type/u8.erobj'),
  (4, 'u16', 1, 16, 0, 'kernel/x86_64/object/type/u16.erobj'),
  (5, 'u32', 1, 32, 0, 'kernel/x86_64/object/type/u32.erobj'),
  (6, 'u64', 1, 64, 0, 'kernel/x86_64/object/type/u64.erobj'),
  (7, 'u128', 1, 128, 0, 'kernel/x86_64/object/type/u128.erobj'),
  (8, 'u256', 1, 256, 0, 'kernel/x86_64/object/type/u256.erobj'),
  (9, 'u512', 1, 512, 0, 'kernel/x86_64/object/type/u512.erobj'),
  (20, 'i8', 2, 8, 1, 'kernel/x86_64/object/type/i8.erobj'),
  (21, 'i16', 2, 16, 1, 'kernel/x86_64/object/type/i16.erobj'),
  (22, 'i32', 2, 32, 1, 'kernel/x86_64/object/type/i32.erobj'),
  (23, 'i64', 2, 64, 1, 'kernel/x86_64/object/type/i64.erobj'),
  (24, 'i128', 2, 128, 1, 'kernel/x86_64/object/type/i128.erobj'),
  (40, 'f16', 3, 16, 0, 'kernel/x86_64/object/type/f16.erobj'),
  (41, 'f32', 3, 32, 0, 'kernel/x86_64/object/type/f32.erobj'),
  (42, 'f64', 3, 64, 0, 'kernel/x86_64/object/type/f64.erobj'),
  (43, 'f80', 3, 80, 0, 'kernel/x86_64/object/type/f80.erobj'),
  (44, 'f128', 3, 128, 0, 'kernel/x86_64/object/type/f128.erobj'),
  (60, 'ptr16', 4, 16, 0, 'kernel/x86_64/object/type/ptr16.erobj'),
  (61, 'ptr32', 4, 32, 0, 'kernel/x86_64/object/type/ptr32.erobj'),
  (62, 'ptr64', 4, 64, 0, 'kernel/x86_64/object/type/ptr64.erobj'),
  (70, 'rel8', 5, 8, 0, 'kernel/x86_64/object/type/rel8.erobj'),
  (71, 'rel16', 5, 16, 0, 'kernel/x86_64/object/type/rel16.erobj'),
  (72, 'rel32', 5, 32, 0, 'kernel/x86_64/object/type/rel32.erobj'),
  (73, 'rel64', 5, 64, 0, 'kernel/x86_64/object/type/rel64.erobj'),
  (100, 'wasm_i32', 6, 32, 0, 'kernel/x86_64/object/type/wasm_i32.erobj'),
  (101, 'wasm_i64', 6, 64, 0, 'kernel/x86_64/object/type/wasm_i64.erobj'),
  (102, 'wasm_f32', 6, 32, 0, 'kernel/x86_64/object/type/wasm_f32.erobj'),
  (103, 'wasm_f64', 6, 64, 0, 'kernel/x86_64/object/type/wasm_f64.erobj'),
  (104, 'wasm_v128', 6, 128, 0, 'kernel/x86_64/object/type/wasm_v128.erobj'),
  (105, 'wasm_funcref', 7, 64, 0, 'kernel/x86_64/object/type/wasm_funcref.erobj'),
  (106, 'wasm_externref', 7, 64, 0, 'kernel/x86_64/object/type/wasm_externref.erobj'),
  (120, 'flags', 8, 0, 0, 'kernel/x86_64/object/type/flags.erobj'),
  (121, 'memory', 9, 0, 0, 'kernel/x86_64/object/type/memory.erobj'),
  (122, 'table', 10, 0, 0, 'kernel/x86_64/object/type/table.erobj'),
  (123, 'label', 11, 0, 0, 'kernel/x86_64/object/type/label.erobj'),
  (124, 'import_ref', 12, 0, 0, 'kernel/x86_64/object/type/import_ref.erobj'),
  (125, 'data_ref', 13, 0, 0, 'kernel/x86_64/object/type/data_ref.erobj');

create table operand_kind_object (
  operand_kind_id integer primary key,
  name text not null unique,
  flags integer not null default 0,
  default_type_id integer references value_type(type_id),
  object_path text not null unique
);

insert into operand_kind_object(operand_kind_id, name, flags, default_type_id, object_path) values
  (1, 'none', 0, 1, 'kernel/x86_64/object/operand_kind/none.erobj'),
  (2, 'register', 1, null, 'kernel/x86_64/object/operand_kind/register.erobj'),
  (3, 'immediate', 2, null, 'kernel/x86_64/object/operand_kind/immediate.erobj'),
  (4, 'memory', 4, 121, 'kernel/x86_64/object/operand_kind/memory.erobj'),
  (5, 'branch_target', 8, 123, 'kernel/x86_64/object/operand_kind/branch_target.erobj'),
  (6, 'label', 8, 123, 'kernel/x86_64/object/operand_kind/label.erobj'),
  (7, 'data_ref', 16, 125, 'kernel/x86_64/object/operand_kind/data_ref.erobj'),
  (8, 'import_ref', 32, 124, 'kernel/x86_64/object/operand_kind/import_ref.erobj'),
  (9, 'register_list', 64, null, 'kernel/x86_64/object/operand_kind/register_list.erobj'),
  (10, 'condition_code', 128, 120, 'kernel/x86_64/object/operand_kind/condition_code.erobj'),
  (20, 'wasm_local_index', 256, 100, 'kernel/x86_64/object/operand_kind/wasm_local_index.erobj'),
  (21, 'wasm_global_index', 512, 100, 'kernel/x86_64/object/operand_kind/wasm_global_index.erobj'),
  (22, 'wasm_table_index', 1024, 100, 'kernel/x86_64/object/operand_kind/wasm_table_index.erobj'),
  (23, 'wasm_memory_index', 2048, 100, 'kernel/x86_64/object/operand_kind/wasm_memory_index.erobj'),
  (24, 'wasm_block_type', 4096, 123, 'kernel/x86_64/object/operand_kind/wasm_block_type.erobj'),
  (25, 'wasm_memarg', 8192, 121, 'kernel/x86_64/object/operand_kind/wasm_memarg.erobj'),
  (26, 'wasm_value_stack', 16384, null, 'kernel/x86_64/object/operand_kind/wasm_value_stack.erobj');

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
  (1, 'gpr'),
  (2, 'program_counter'),
  (3, 'flags'),
  (4, 'segment'),
  (5, 'control'),
  (6, 'debug'),
  (7, 'x87'),
  (8, 'mmx'),
  (9, 'vector'),
  (10, 'mask'),
  (20, 'wasm_stack'),
  (21, 'wasm_index_space'),
  (22, 'wasm_memory'),
  (23, 'wasm_table'),
  (24, 'wasm_value_type'),
  (25, 'wasm_ref_type');

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
  (1, 213, 'kernel/x86_64/object/register_set/x86_64.erobj'),
  (2, 73,  'kernel/x86_64/object/register_set/x86_32.erobj'),
  (3, 260, 'kernel/x86_64/object/register_set/aarch64.erobj'),
  (4, 101, 'kernel/x86_64/object/register_set/arm32.erobj'),
  (5, 13,  'kernel/x86_64/object/register_set/wasm.erobj');

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
  (1, 'none', 1, 1, null, 0, null, 0, 0, 'kernel/x86_64/object/operand/none.erobj'),
  (100, 'x86_64_eax', 2, 5, 1, 101, null, 0, 0, 'kernel/x86_64/object/operand/x86_64/eax.erobj'),
  (101, 'x86_64_rax', 2, 6, 1, 1, null, 0, 0, 'kernel/x86_64/object/operand/x86_64/rax.erobj'),
  (102, 'x86_64_imm32_42', 3, 5, 1, 0, null, 42, 0, 'kernel/x86_64/object/operand/x86_64/imm32_42.erobj'),
  (103, 'x86_64_imm32_0', 3, 5, 1, 0, null, 0, 0, 'kernel/x86_64/object/operand/x86_64/imm32_0.erobj'),
  (200, 'x86_32_eax', 2, 5, 2, 1, null, 0, 0, 'kernel/x86_64/object/operand/x86_32/eax.erobj'),
  (201, 'x86_32_imm32_42', 3, 5, 2, 0, null, 42, 0, 'kernel/x86_64/object/operand/x86_32/imm32_42.erobj'),
  (300, 'aarch64_x0', 2, 6, 3, 1, null, 0, 0, 'kernel/x86_64/object/operand/aarch64/x0.erobj'),
  (301, 'aarch64_x30', 2, 6, 3, 31, null, 0, 0, 'kernel/x86_64/object/operand/aarch64/x30.erobj'),
  (302, 'aarch64_imm12_0', 3, 5, 3, 0, null, 0, 0, 'kernel/x86_64/object/operand/aarch64/imm12_0.erobj'),
  (400, 'arm32_r0', 2, 5, 4, 1, null, 0, 0, 'kernel/x86_64/object/operand/arm32/r0.erobj'),
  (401, 'arm32_lr', 2, 5, 4, 101, null, 0, 0, 'kernel/x86_64/object/operand/arm32/lr.erobj'),
  (402, 'arm32_imm12_0', 3, 5, 4, 0, null, 0, 0, 'kernel/x86_64/object/operand/arm32/imm12_0.erobj'),
  (500, 'wasm_none', 1, 1, 5, 0, null, 0, 0, 'kernel/x86_64/object/operand/wasm/none.erobj'),
  (501, 'wasm_i32_const_42', 3, 100, 5, 0, null, 42, 0, 'kernel/x86_64/object/operand/wasm/i32_const_42.erobj'),
  (502, 'wasm_local_index_0', 20, 100, 5, 0, null, 0, 0, 'kernel/x86_64/object/operand/wasm/local_index_0.erobj');

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
  (1, 'x86_64_mov_eax_imm32', 1, 1, 'b8', 5, 1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_eax_imm32.erobj'),
  (2, 'x86_64_ret', 1, 1, 'c3', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/ret.erobj'),
  (3, 'x86_64_nop', 1, 1, '90', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/nop.erobj'),
  (82, 'x86_64_mov_rcx_rsi', 1, 1, '4889f1', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/mov_rcx_rsi.erobj'),
  (83, 'x86_64_sub_rcx_rdi', 1, 1, '4829f9', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/sub_rcx_rdi.erobj'),
  (84, 'x86_64_jle_rel8_10', 1, 1, '7e0a', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/jle_rel8_10.erobj'),
  (85, 'x86_64_xor_eax_eax', 1, 1, '31c0', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/xor_eax_eax.erobj'),
  (86, 'x86_64_cld', 1, 1, 'fc', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/cld.erobj'),
  (87, 'x86_64_shr_rcx_3', 1, 1, '48c1e903', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/shr_rcx_3.erobj'),
  (88, 'x86_64_rep_stosq', 1, 1, 'f348ab', null, -1, 0, 'kernel/x86_64/object/encoding/x86_64/rep_stosq.erobj'),
  (20, 'x86_32_mov_eax_imm32', 2, 1, 'b8', 5, 1, 0, 'kernel/x86_64/object/encoding/x86_32/mov_eax_imm32.erobj'),
  (21, 'x86_32_ret', 2, 1, 'c3', null, -1, 0, 'kernel/x86_64/object/encoding/x86_32/ret.erobj'),
  (40, 'aarch64_ret', 3, 2, 'c0035fd6', null, -1, 0, 'kernel/x86_64/object/encoding/aarch64/ret.erobj'),
  (41, 'aarch64_nop', 3, 2, '1f2003d5', null, -1, 0, 'kernel/x86_64/object/encoding/aarch64/nop.erobj'),
  (60, 'arm32_bx_lr', 4, 2, '1eff2fe1', null, -1, 0, 'kernel/x86_64/object/encoding/arm32/bx_lr.erobj'),
  (61, 'arm32_nop', 4, 2, '00f020e3', null, -1, 0, 'kernel/x86_64/object/encoding/arm32/nop.erobj'),
  (80, 'wasm_end', 5, 3, '0b', null, -1, 0, 'kernel/x86_64/object/encoding/wasm/end.erobj'),
  (81, 'wasm_nop', 5, 3, '01', null, -1, 0, 'kernel/x86_64/object/encoding/wasm/nop.erobj');

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
  (1, 1, 1, 1, 'kernel/x86_64/object/form/x86_64/mov_eax_imm32.erobj', 1),
  (1, 2, 2, 1, 'kernel/x86_64/object/form/x86_64/ret.erobj', 2);

insert into function_operand(function_id, record_id, operand_index, operand_id) values
  (1, 1, 0, 100),
  (1, 1, 1, 102),
  (1, 2, 0, 1);

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

-- SQL parser/import tool model.
--
-- The active authority is the query tool operating over these relations. Source
-- bytes are input data. Token, parse, abstraction, and lowering rows are the
-- program state the tool derives and edits. Unsupported syntax has no grammar
-- or semantic rule and therefore cannot be imported.

create table source_unit (
  source_unit_id integer primary key,
  language_id integer not null references language(language_id),
  name text not null unique,
  source_text text not null,
  root_parse_node_id integer,
  root_abstraction_id integer
);

create table token_kind (
  token_kind_id integer primary key,
  language_id integer not null references language(language_id),
  name text not null,
  token_class integer not null,
  flags integer not null default 0,
  unique (language_id, name)
);

insert into token_kind(token_kind_id, language_id, name, token_class, flags) values
  (1, 4, 'kw_int', 1, 0),
  (2, 4, 'kw_void', 1, 0),
  (3, 4, 'kw_return', 1, 0),
  (4, 4, 'identifier', 2, 0),
  (5, 4, 'integer_literal', 3, 0),
  (6, 4, 'lparen', 4, 0),
  (7, 4, 'rparen', 4, 0),
  (8, 4, 'lbrace', 4, 0),
  (9, 4, 'rbrace', 4, 0),
  (10, 4, 'semicolon', 4, 0);

create table lex_rule (
  lex_rule_id integer primary key,
  language_id integer not null references language(language_id),
  token_kind_id integer not null references token_kind(token_kind_id),
  rule_name text not null,
  priority integer not null,
  literal_text text,
  char_class text,
  skip_flag integer not null default 0,
  unique (language_id, rule_name)
);

insert into lex_rule(lex_rule_id, language_id, token_kind_id, rule_name, priority, literal_text, char_class, skip_flag) values
  (1, 4, 1, 'literal_int', 1, 'int', null, 0),
  (2, 4, 2, 'literal_void', 1, 'void', null, 0),
  (3, 4, 3, 'literal_return', 1, 'return', null, 0),
  (4, 4, 6, 'literal_lparen', 1, '(', null, 0),
  (5, 4, 7, 'literal_rparen', 1, ')', null, 0),
  (6, 4, 8, 'literal_lbrace', 1, '{', null, 0),
  (7, 4, 9, 'literal_rbrace', 1, '}', null, 0),
  (8, 4, 10, 'literal_semicolon', 1, ';', null, 0),
  (9, 4, 5, 'decimal_integer', 2, null, '0-9+', 0),
  (10, 4, 4, 'identifier', 3, null, 'A-Za-z_ A-Za-z0-9_*', 0);

create table token (
  source_unit_id integer not null references source_unit(source_unit_id),
  token_id integer not null,
  token_kind_id integer not null references token_kind(token_kind_id),
  start_offset integer not null,
  end_offset integer not null,
  text_value text not null,
  int_value integer,
  primary key (source_unit_id, token_id),
  unique (source_unit_id, start_offset)
);

create table grammar_rule (
  grammar_rule_id integer primary key,
  language_id integer not null references language(language_id),
  nonterminal text not null,
  production_name text not null,
  syntax_atom_id integer references syntax_atom(syntax_atom_id),
  arity integer not null,
  unique (language_id, nonterminal, production_name)
);

create table grammar_rule_part (
  grammar_rule_id integer not null references grammar_rule(grammar_rule_id),
  position integer not null,
  expected_token_kind_id integer references token_kind(token_kind_id),
  expected_nonterminal text,
  min_count integer not null default 1,
  max_count integer not null default 1,
  primary key (grammar_rule_id, position)
);

insert into grammar_rule(grammar_rule_id, language_id, nonterminal, production_name, syntax_atom_id, arity) values
  (1, 4, 'translation_unit', 'single_function', 20, 1),
  (2, 4, 'function_definition', 'int_fn_void_body', 21, 6),
  (3, 4, 'compound_statement', 'single_return', 22, 3),
  (4, 4, 'return_statement', 'return_integer', 23, 3),
  (5, 4, 'integer_expression', 'integer_literal', 24, 1);

insert into grammar_rule_part(grammar_rule_id, position, expected_token_kind_id, expected_nonterminal, min_count, max_count) values
  (1, 1, null, 'function_definition', 1, 1),
  (2, 1, 1, null, 1, 1),
  (2, 2, 4, null, 1, 1),
  (2, 3, 6, null, 1, 1),
  (2, 4, 2, null, 1, 1),
  (2, 5, 7, null, 1, 1),
  (2, 6, null, 'compound_statement', 1, 1),
  (3, 1, 8, null, 1, 1),
  (3, 2, null, 'return_statement', 1, 1),
  (3, 3, 9, null, 1, 1),
  (4, 1, 3, null, 1, 1),
  (4, 2, null, 'integer_expression', 1, 1),
  (4, 3, 10, null, 1, 1),
  (5, 1, 5, null, 1, 1);

create table parse_node (
  source_unit_id integer not null references source_unit(source_unit_id),
  parse_node_id integer not null,
  grammar_rule_id integer not null references grammar_rule(grammar_rule_id),
  syntax_atom_id integer references syntax_atom(syntax_atom_id),
  start_token_id integer not null,
  end_token_id integer not null,
  primary key (source_unit_id, parse_node_id)
);

create table parse_edge (
  source_unit_id integer not null,
  parent_parse_node_id integer not null,
  child_parse_node_id integer not null,
  ordinal integer not null,
  primary key (source_unit_id, parent_parse_node_id, ordinal),
  foreign key (source_unit_id, parent_parse_node_id) references parse_node(source_unit_id, parse_node_id),
  foreign key (source_unit_id, child_parse_node_id) references parse_node(source_unit_id, parse_node_id)
);

insert into source_unit(source_unit_id, language_id, name, source_text, root_parse_node_id, root_abstraction_id) values
  (1, 4, 'return_42.c', 'int return_42(void) { return 42; }', 1, 2);

insert into token(source_unit_id, token_id, token_kind_id, start_offset, end_offset, text_value, int_value) values
  (1, 1, 1, 0, 3, 'int', null),
  (1, 2, 4, 4, 13, 'return_42', null),
  (1, 3, 6, 13, 14, '(', null),
  (1, 4, 2, 14, 18, 'void', null),
  (1, 5, 7, 18, 19, ')', null),
  (1, 6, 8, 20, 21, '{', null),
  (1, 7, 3, 22, 28, 'return', null),
  (1, 8, 5, 29, 31, '42', 42),
  (1, 9, 10, 31, 32, ';', null),
  (1, 10, 9, 33, 34, '}', null);

insert into parse_node(source_unit_id, parse_node_id, grammar_rule_id, syntax_atom_id, start_token_id, end_token_id) values
  (1, 1, 1, 20, 1, 10),
  (1, 2, 2, 21, 1, 10),
  (1, 3, 3, 22, 6, 10),
  (1, 4, 4, 23, 7, 9),
  (1, 5, 5, 24, 8, 8);

insert into parse_edge(source_unit_id, parent_parse_node_id, child_parse_node_id, ordinal) values
  (1, 1, 2, 1),
  (1, 2, 3, 1),
  (1, 3, 4, 1),
  (1, 4, 5, 1);

create view source_token_stream as
select source_unit.name as source_name,
       token.token_id,
       token_kind.name as token_kind,
       token.text_value,
       token.int_value
from token
join source_unit using (source_unit_id)
join token_kind using (token_kind_id)
order by source_unit.source_unit_id, token.token_id;

create view source_parse_tree as
select source_unit.name as source_name,
       parse_node.parse_node_id,
       grammar_rule.nonterminal,
       grammar_rule.production_name,
       syntax_atom.name as syntax_atom,
       parse_node.start_token_id,
       parse_node.end_token_id
from parse_node
join source_unit using (source_unit_id)
join grammar_rule using (grammar_rule_id)
left join syntax_atom using (syntax_atom_id)
order by source_unit.source_unit_id, parse_node.parse_node_id;

create view parsed_source_abstractions as
select source_unit.name as source_name,
       abstraction_node.name as abstraction_name,
       abstraction_kind.name as abstraction_kind,
       abstraction_node.literal_integer,
       abstraction_node.object_path
from source_unit
join abstraction_node on abstraction_node.import_unit_id = source_unit.source_unit_id
join abstraction_kind using (abstraction_kind_id)
order by abstraction_node.abstraction_id;

create view source_to_target_hex as
select source_unit.name as source_name,
       language.name as language_name,
       isa.name as target_isa,
       abstraction_function_projection.function_name,
       abstraction_function_projection.hex_bytes
from source_unit
join language using (language_id)
join abstraction_node on abstraction_node.abstraction_id = source_unit.root_abstraction_id
join abstraction_function_projection on abstraction_function_projection.abstraction_name = abstraction_node.name
join function_object on function_object.name = abstraction_function_projection.function_name
join isa on isa.isa_id = function_object.isa_id;

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
  source_unit_id integer references source_unit(source_unit_id),
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
  (24, 3, 'er_push', null, null, null, null, 'asm_dsl_macro_er_push', null, 2);

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

insert into source_unit(source_unit_id, language_id, name, source_text, root_parse_node_id, root_abstraction_id) values
  (2, 7, 'kernel/test/test_flat_runtime.asm.erobj', 'er_fn er_bss_zero\n    mov rcx, rsi\n    sub rcx, rdi\n    jle .done\n    xor eax, eax\n    cld\n    shr rcx, 3\n    rep stosq\n.done:\n    ret\n', null, null);

insert into asm_dsl_source(asm_source_id, source_unit_id, source_object_path, module_name, language_id) values
  (1, 2, 'kernel/test/test_flat_runtime.asm.erobj', 'kernel_test_flat_runtime', 7);

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
  select repo_file_id, 1, replace(cast(content as text), char(13), '') || char(10), ''
  from repo_file
  where file_kind = 'asm'
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

insert into repo_asm_function_decl(repo_file_id, line_no, function_name, declaration_text)
select repo_file_id,
       line_no,
       trim(substr(trim(text), 7)),
       text
from repo_asm_line
where trim(text) glob 'er_fn *'
  and trim(substr(trim(text), 7)) <> '';

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

create view repo_asm_operation as
with trimmed as (
  select path, repo_file_id, function_name, line_no, text, trim(text) as t
  from repo_asm_function_lines
), parsed as (
  select path,
         repo_file_id,
         function_name,
         line_no,
         text,
         t,
         case
           when t = '' then 0
           when substr(t,1,1) = ';' then 0
           when t glob '.*:' then 2
           when t glob '%include*' then 4
           when t glob '* equ *' then 5
           when t glob 'er_fn *' then 1
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
           else trim(substr(t, instr(t, ' ') + 1))
         end as operand_text
  from trimmed
)
select path, repo_file_id, function_name, line_no, line_kind, op_name, operand_text, text as raw_text
from parsed
where line_kind <> 0;

create view repo_asm_rule_gaps as
select repo_asm_operation.path,
       repo_asm_operation.function_name,
       repo_asm_operation.line_no,
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

create view browser_spec_fact_summary as
select 'source' as fact_kind, namespace as subject, 1 as fact_count, byte_len
from browser_spec_source
union all
select 'html_tokenizer_transition', 'html.tokenizer', count(*), null from browser_html_tokenizer_transition
union all
select 'html_tokenizer_action', 'html.tokenizer', count(*), null from browser_html_tokenizer_action
union all
select 'html_tree_rule', 'html.tree_builder', count(*), null from browser_html_tree_rule
union all
select 'html_tree_rule_action', 'html.tree_builder', count(*), null from browser_html_tree_rule_action
union all
select 'html_named_entity', 'html.entities', count(*), null from browser_html_named_entity
union all
select 'html_element', 'html.elements', count(*), null from browser_html_element_fact
union all
select 'css_property', 'css.properties', count(*), null from browser_css_property_fact
union all
select 'css_selector', 'css.selectors', count(*), null from browser_css_selector_fact
union all
select 'fetch_field', 'fetch', count(*), null from browser_fetch_field_fact
union all
select 'ecmascript_builtin', 'ecmascript', count(*), null from browser_ecmascript_builtin_fact;

create view browser_spec_lookup_proofs as
select 'tokenizer_lt_from_data' as proof_name,
       current_state || '+' || char_class || '->' || next_state as proof_value
from browser_html_tokenizer_transition
where current_state = 'DATA_STATE' and char_class = 'CHAR_CLASS_LT'
union all
select 'entity_amp', name || '=' || cast(code_point_1 as text)
from browser_html_named_entity
where name = 'AMP'
union all
select 'element_div', tag_name || '=' || dom_interface
from browser_html_element_fact
where tag_name = 'div'
union all
select 'css_background_color', name || '=' || initial_value
from browser_css_property_fact
where name = 'background-color'
union all
select 'fetch_request_method', name || ':' || field_type
from browser_fetch_field_fact
where object_kind = 'request_init' and name = 'method'
union all
select 'ecmascript_object', name || ':' || constructor_signature
from browser_ecmascript_builtin_fact
where name = 'Object';

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

create view browser_spec_extended_fact_summary as
select * from browser_spec_fact_summary
union all
select 'url_parser_state', 'url', count(*), null from browser_url_parser_state_fact
union all
select 'url_property', 'url', count(*), null from browser_url_property_fact
union all
select 'encoding', 'encoding', count(*), null from browser_encoding_fact
union all
select 'encoding_label', 'encoding', count(*), null from browser_encoding_label_fact
union all
select 'dom_interface', 'dom', count(*), null from browser_dom_interface_fact
union all
select 'dom_attribute', 'dom', count(*), null from browser_dom_attribute_fact
union all
select 'dom_method', 'dom', count(*), null from browser_dom_method_fact;

create view browser_spec_extended_lookup_proofs as
select * from browser_spec_lookup_proofs
union all
select 'url_state_scheme_start', name from browser_url_parser_state_fact where name = 'SchemeStart'
union all
select 'encoding_utf8_label', name || ':' || label
from browser_encoding_fact join browser_encoding_label_fact using (encoding_id)
where browser_encoding_fact.name = 'UTF-8' and browser_encoding_label_fact.label = 'utf-8'
union all
select 'dom_interface_event', name || ':' || parent
from browser_dom_interface_fact
where name = 'Event';

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
  (1, 'udp', 'User Datagram Protocol', 'transport', 'Connectionless transport datagram format over IP.'),
  (2, 'tftp', 'Trivial File Transfer Protocol', 'application', 'Simple lock-step file transfer over UDP.'),
  (3, 'hpack', 'HPACK', 'presentation', 'Header compression format for HTTP/2.'),
  (4, 'quic', 'QUIC', 'transport', 'UDP-based multiplexed secure transport.');

insert or ignore into edgerun_protocol_fact(protocol_id, id, name, layer, summary) values
  (5, 'ethernet', 'Ethernet', 'link', 'Link-layer Ethernet frame transport.'),
  (6, 'arp', 'Address Resolution Protocol', 'link', 'IPv4 address resolution over link-layer networks.'),
  (7, 'ipv4', 'Internet Protocol Version 4', 'network', 'IPv4 packet format and routing semantics.'),
  (8, 'ipv6', 'Internet Protocol Version 6', 'network', 'IPv6 packet format and routing semantics.'),
  (9, 'icmpv4', 'Internet Control Message Protocol for IPv4', 'network', 'ICMP control messages for IPv4.'),
  (10, 'icmpv6', 'Internet Control Message Protocol for IPv6', 'network', 'ICMP control messages for IPv6.'),
  (11, 'tcp', 'Transmission Control Protocol', 'transport', 'Reliable ordered byte stream over IP.'),
  (12, 'dns', 'Domain Name System', 'application', 'Domain name query and resource record protocol.'),
  (13, 'dhcpv4', 'Dynamic Host Configuration Protocol for IPv4', 'application', 'IPv4 host configuration over UDP.'),
  (14, 'dhcpv6', 'Dynamic Host Configuration Protocol for IPv6', 'application', 'IPv6 host configuration over UDP.'),
  (15, 'http', 'HTTP', 'application', 'Application semantics and message mappings for HTTP/1.1, HTTP/2, and HTTP/3.'),
  (16, 'nfc', 'Near Field Communication', 'link', 'Near-field radio communication protocols.'),
  (17, 'qpack', 'QPACK', 'presentation', 'Header compression format for HTTP/3.'),
  (18, 'tls', 'Transport Layer Security', 'security', 'Authenticated encrypted transport security protocol.');

create table edgerun_protocol_dependency_fact (
  protocol_id integer not null references edgerun_protocol_fact(protocol_id),
  dependency text not null,
  edge_kind text not null,
  primary key (protocol_id, dependency, edge_kind)
);

insert into edgerun_protocol_dependency_fact(protocol_id, dependency, edge_kind) values
  (1, 'IPv4', 'runs_over'),
  (1, 'IPv6', 'runs_over'),
  (2, 'UDP', 'runs_over'),
  (3, 'HTTP/2', 'runs_over'),
  (4, 'UDP', 'runs_over'),
  (4, 'TLS 1.3', 'depends_on');

insert or ignore into edgerun_protocol_dependency_fact(protocol_id, dependency, edge_kind) values
  (6, 'Ethernet', 'runs_over'),
  (7, 'Ethernet', 'runs_over'),
  (8, 'Ethernet', 'runs_over'),
  (9, 'IPv4', 'runs_over'),
  (10, 'IPv6', 'runs_over'),
  (11, 'IPv4', 'runs_over'),
  (11, 'IPv6', 'runs_over'),
  (12, 'UDP', 'runs_over'),
  (12, 'TCP', 'runs_over'),
  (12, 'TLS', 'runs_over'),
  (12, 'HTTPS', 'runs_over'),
  (12, 'QUIC', 'runs_over'),
  (13, 'UDP', 'runs_over'),
  (13, 'IPv4', 'runs_over'),
  (14, 'UDP', 'runs_over'),
  (14, 'IPv6', 'runs_over'),
  (15, 'TCP', 'runs_over'),
  (15, 'TLS', 'runs_over'),
  (15, 'QUIC', 'runs_over'),
  (17, 'HTTP/3', 'runs_over'),
  (17, 'QUIC', 'runs_over'),
  (18, 'TCP', 'runs_over'),
  (18, 'QUIC', 'runs_over');

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
  (1, 1, 'udp-header-parse', 'packet-format', 'unknown'),
  (2, 1, 'udp-checksum', 'checksum', 'unknown'),
  (3, 2, 'tftp-message-parse', 'message-format', 'unknown'),
  (4, 3, 'hpack-integer-codec', 'codec', 'unknown'),
  (5, 3, 'hpack-dynamic-table', 'state-machine', 'unknown'),
  (6, 4, 'quic-varint', 'codec', 'unknown'),
  (7, 15, 'http-message-parsing', 'message-format', 'unknown'),
  (8, 15, 'http-content-coding', 'semantics', 'unknown'),
  (9, 17, 'qpack-integer-codec', 'codec', 'unknown'),
  (10, 18, 'tls-record-parse', 'record-format', 'unknown');

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
  (1, 1, 1, 0, 0, 0, 'plausible'),
  (2, 1, 0, 0, 0, 0, 'plausible'),
  (3, 0, 0, 0, 0, 1, 'plausible-with-alloc'),
  (4, 1, 1, 1, 1, 1, 'complex'),
  (5, 1, 1, 0, 0, 0, 'plausible'),
  (6, 1, 1, 0, 0, 0, 'plausible'),
  (7, 1, 1, 0, 0, 0, 'plausible'),
  (8, 1, 1, 0, 0, 0, 'plausible'),
  (9, 1, 1, 0, 0, 0, 'plausible'),
  (10, 1, 1, 0, 0, 0, 'plausible'),
  (11, 1, 1, 1, 0, 1, 'plausible-with-alloc'),
  (12, 1, 1, 1, 0, 1, 'plausible-with-alloc'),
  (13, 1, 1, 0, 0, 1, 'plausible-with-alloc'),
  (14, 1, 1, 0, 0, 1, 'plausible-with-alloc'),
  (15, 1, 0, 1, 0, 1, 'plausible-with-alloc'),
  (16, 1, 1, 0, 0, 0, 'plausible'),
  (17, 0, 0, 0, 0, 1, 'plausible-with-alloc'),
  (18, 1, 0, 1, 1, 1, 'complex');

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
  (1, 'udp-datagram', 'frame', 'RFC768', 'Format'),
  (2, 'tftp-message', 'sum-frame', 'RFC1350', '5');

insert into edgerun_definition_field_fact(definition_id, field_order, name, field_type, length_expr, constraint_expr) values
  (1, 1, 'source_port', 'u16be', '', ''),
  (1, 2, 'destination_port', 'u16be', '', ''),
  (1, 3, 'length', 'u16be', '', 'length >= 8'),
  (1, 4, 'checksum', 'u16be', '', ''),
  (1, 5, 'payload', 'bytes', 'length - 8', ''),
  (2, 1, 'opcode', 'u16be', '', '');

insert into edgerun_definition_variant_fact(definition_id, variant_name, tag_field, tag_value) values
  (2, 'rrq', 'opcode', 1),
  (2, 'wrq', 'opcode', 2),
  (2, 'data', 'opcode', 3),
  (2, 'ack', 'opcode', 4),
  (2, 'error', 'opcode', 5);

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
  (1, 'udp-rfc768-length-0001', 'RFC768', 'Format', 'MUST', 'udp-datagram', 'length >= 8 && length == payload_len + 8', 'UDP_LENGTH_INVALID', 'UDP length does not match header plus payload length.'),
  (2, 'tftp-rfc1350-opcode-0001', 'RFC1350', '5', 'MUST', 'tftp-message', 'byte_len >= 2 && opcode in [1, 2, 3, 4, 5, 6]', 'TFTP_OPCODE_INVALID', 'TFTP opcode is missing or unknown.'),
  (3, 'tftp-rfc1350-ack-length-0001', 'RFC1350', '5', 'MUST', 'tftp-message', 'opcode != 4 || byte_len == 4', 'TFTP_ACK_LENGTH_INVALID', 'TFTP ACK packets must be exactly four octets.'),
  (4, 'tftp-rfc1350-data-length-0001', 'RFC1350', '5', 'MUST', 'tftp-message', 'opcode != 3 || byte_len >= 4', 'TFTP_DATA_LENGTH_INVALID', 'TFTP DATA packets must include a two-octet block number.'),
  (5, 'tftp-message-definition', 'RFC1350', '5', 'MUST', 'tftp-message', 'byte_len >= 2', 'TFTP_MESSAGE_TOO_SHORT', 'TFTP messages must include a two-octet opcode.');

create table edgerun_corpus_case_fact (
  case_id integer primary key,
  corpus_name text not null,
  case_name text not null unique,
  hex_bytes text not null,
  description text not null,
  expect_exit integer not null
);

create table edgerun_corpus_expectation_fact (
  case_id integer not null references edgerun_corpus_case_fact(case_id),
  clause_id integer not null references edgerun_clause_fact(clause_id),
  expected_result text not null,
  primary key (case_id, clause_id)
);

insert into edgerun_corpus_case_fact(case_id, corpus_name, case_name, hex_bytes, description, expect_exit) values
  (1, 'tftp', 'valid-ack', '00040001', 'Valid TFTP ACK for block 1.', 0),
  (2, 'tftp', 'invalid-short', '00', 'TFTP message is shorter than the two-octet opcode.', 2),
  (3, 'tftp', 'invalid-ack-length', '0004000100', 'TFTP ACK opcode with an extra trailing octet.', 2),
  (4, 'tftp', 'invalid-data-length', '0003', 'TFTP DATA opcode without a two-octet block number.', 2),
  (5, 'tftp', 'invalid-opcode', '00090001', 'TFTP message with an unknown opcode.', 2);

insert into edgerun_corpus_expectation_fact(case_id, clause_id, expected_result) values
  (1, 2, 'pass'), (1, 3, 'pass'), (1, 4, 'pass'),
  (2, 5, 'reject'),
  (3, 2, 'pass'), (3, 3, 'reject'), (3, 4, 'pass'),
  (4, 2, 'pass'), (4, 3, 'pass'), (4, 4, 'reject'),
  (5, 2, 'reject'), (5, 3, 'pass'), (5, 4, 'pass');

create view edgerun_tftp_case_fields as
select case_id,
       case_name,
       hex_bytes,
       length(hex_bytes) / 2 as byte_len,
       case when length(hex_bytes) >= 4 then
         ((instr('0123456789abcdef', lower(substr(hex_bytes, 1, 1))) - 1) << 12) |
         ((instr('0123456789abcdef', lower(substr(hex_bytes, 2, 1))) - 1) << 8) |
         ((instr('0123456789abcdef', lower(substr(hex_bytes, 3, 1))) - 1) << 4) |
         (instr('0123456789abcdef', lower(substr(hex_bytes, 4, 1))) - 1)
       else null end as opcode
from edgerun_corpus_case_fact
where corpus_name = 'tftp';

create view edgerun_tftp_clause_results as
select fields.case_id,
       fields.case_name,
       clause.id as clause_name,
       case clause.id
          when 'tftp-rfc1350-opcode-0001' then
            case when fields.byte_len >= 2 and fields.opcode in (1, 2, 3, 4, 5, 6) then 'pass' else 'reject' end
          when 'tftp-message-definition' then
            case when fields.byte_len >= 2 then 'pass' else 'reject' end
         when 'tftp-rfc1350-ack-length-0001' then
           case when fields.opcode != 4 or fields.byte_len = 4 then 'pass' else 'reject' end
         when 'tftp-rfc1350-data-length-0001' then
           case when fields.opcode != 3 or fields.byte_len >= 4 then 'pass' else 'reject' end
       end as actual_result
from edgerun_tftp_case_fields fields
join edgerun_clause_fact clause on clause.subject = 'tftp-message';

create view edgerun_tftp_corpus_proof as
select results.case_name,
       results.clause_name,
       expected.expected_result,
       results.actual_result,
       case when expected.expected_result = results.actual_result then 1 else 0 end as matches_expectation
from edgerun_tftp_clause_results results
left join edgerun_corpus_expectation_fact expected
  on expected.case_id = results.case_id
 and expected.clause_id = (select clause_id from edgerun_clause_fact where id = results.clause_name)
where expected.expected_result is not null;

create table engine_field_type_fact (
  field_type text primary key,
  byte_len integer not null,
  endian text not null
);

insert into engine_field_type_fact(field_type, byte_len, endian) values
  ('u16be', 2, 'big');

create table engine_corpus_definition_binding_fact (
  corpus_name text not null,
  definition_id text not null,
  base_byte_offset integer not null,
  primary key (corpus_name, definition_id)
);

insert into engine_corpus_definition_binding_fact(corpus_name, definition_id, base_byte_offset) values
  ('tftp', 'tftp-message', 0),
  ('udp-tftp', 'udp-datagram', 0),
  ('udp-tftp', 'tftp-message', 8);

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

create table engine_clause_predicate_atom_fact (
  clause_id integer not null references edgerun_clause_fact(clause_id),
  group_index integer not null,
  atom_index integer not null,
  lhs_name text not null,
  operator_name text not null,
  rhs_integer integer,
  rhs_value_name text not null default '',
  rhs_integer_add integer not null default 0,
  rhs_set_csv text not null default '',
  primary key (clause_id, group_index, atom_index)
);

insert into engine_clause_predicate_atom_fact(clause_id, group_index, atom_index, lhs_name, operator_name, rhs_integer, rhs_value_name, rhs_integer_add, rhs_set_csv) values
  (1, 1, 1, 'length', '>=', 8, '', 0, ''),
  (1, 1, 2, 'length', '==', null, 'payload_len', 8, ''),
  (2, 1, 1, 'byte_len', '>=', 2, '', 0, ''),
  (2, 1, 2, 'opcode', 'in', null, '', 0, '1,2,3,4,5,6'),
  (3, 1, 1, 'opcode', '!=', 4, '', 0, ''),
  (3, 2, 1, 'byte_len', '==', 4, '', 0, ''),
  (4, 1, 1, 'opcode', '!=', 3, '', 0, ''),
  (4, 2, 1, 'byte_len', '>=', 4, '', 0, ''),
  (5, 1, 1, 'byte_len', '>=', 2, '', 0, '');

create view engine_corpus_case_fact as
select corpus_name,
       case_name,
       hex_bytes,
       length(hex_bytes) / 2 as byte_len,
       description,
       expect_exit
from edgerun_corpus_case_fact
union all
select derived.corpus_name,
       derived.case_name,
       replace(replace(trim(cast(hex_source.content as text)), char(10), ''), char(13), ''),
       length(replace(replace(trim(cast(hex_source.content as text)), char(10), ''), char(13), '')) / 2,
       derived.description,
       derived.expect_exit
from toml_derived_corpus_case_fact derived
join edgerun_standards_source hex_source
  on hex_source.path like '%/standards/corpus/' || derived.corpus_name || '/' || derived.file_name
where not exists (
  select 1
  from edgerun_corpus_case_fact curated
  where curated.corpus_name = derived.corpus_name
    and curated.case_name = derived.case_name
);

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
select corpus_name,
       case_name,
       binding.definition_id,
       'byte_len' as value_name,
       byte_len - binding.base_byte_offset as integer_value
from engine_corpus_case_fact
join engine_corpus_definition_binding_fact binding using (corpus_name)
union all
select corpus_name,
       case_name,
       definition_id,
       field_name,
       integer_value
from engine_extracted_field_fact
where integer_value is not null
union all
select corpus.corpus_name,
       corpus.case_name,
       binding.definition_id,
       'payload_len',
       corpus.byte_len - binding.base_byte_offset - 8
from engine_corpus_case_fact corpus
join engine_corpus_definition_binding_fact binding using (corpus_name)
where binding.definition_id = 'udp-datagram';

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
         when 'in' then case when instr(',' || atom.rhs_set_csv || ',', ',' || cast(value.integer_value as text) || ',') > 0 then 1 else 0 end
         else 0
       end as atom_matches
from toml_derived_corpus_expectation_fact expected
join edgerun_clause_fact clause on clause.id = expected.clause_name
join engine_clause_predicate_atom_fact atom using (clause_id)
left join engine_case_value_fact value
  on value.corpus_name = expected.corpus_name
 and value.case_name = expected.case_name
 and value.definition_id = clause.subject
 and value.value_name = atom.lhs_name
left join engine_case_value_fact rhs_value
  on rhs_value.corpus_name = expected.corpus_name
 and rhs_value.case_name = expected.case_name
 and rhs_value.definition_id = clause.subject
 and rhs_value.value_name = atom.rhs_value_name;

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
from toml_derived_corpus_expectation_fact expected
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
  (1, ':authority', ''),
  (2, ':method', 'GET'),
  (3, ':method', 'POST'),
  (4, ':path', '/'),
  (5, ':path', '/index.html'),
  (6, ':scheme', 'http'),
  (7, ':scheme', 'https'),
  (8, ':status', '200'),
  (9, ':status', '204'),
  (10, ':status', '206'),
  (11, ':status', '304'),
  (12, ':status', '400'),
  (13, ':status', '404'),
  (14, ':status', '500'),
  (15, 'accept-', ''),
  (16, 'accept-encoding', 'gzip, deflate'),
  (17, 'accept-language', ''),
  (18, 'accept-ranges', ''),
  (19, 'accept', ''),
  (20, 'access-control-allow-origin', ''),
  (21, 'age', ''),
  (22, 'allow', ''),
  (23, 'authorization', ''),
  (24, 'cache-control', ''),
  (25, 'content-disposition', ''),
  (26, 'content-encoding', ''),
  (27, 'content-language', ''),
  (28, 'content-length', ''),
  (29, 'content-location', ''),
  (30, 'content-range', ''),
  (31, 'content-type', ''),
  (32, 'cookie', ''),
  (33, 'date', ''),
  (34, 'etag', ''),
  (35, 'expect', ''),
  (36, 'expires', ''),
  (37, 'from', ''),
  (38, 'host', ''),
  (39, 'if-match', ''),
  (40, 'if-modified-since', ''),
  (41, 'if-none-match', ''),
  (42, 'if-range', ''),
  (43, 'if-unmodified-since', ''),
  (44, 'last-modified', ''),
  (45, 'link', ''),
  (46, 'location', ''),
  (47, 'max-forwards', ''),
  (48, 'proxy-authenticate', ''),
  (49, 'proxy-authorization', ''),
  (50, 'range', ''),
  (51, 'referer', ''),
  (52, 'refresh', ''),
  (53, 'retry-after', ''),
  (54, 'server', ''),
  (55, 'set-cookie', ''),
  (56, 'strict-transport-security', ''),
  (57, 'transfer-encoding', ''),
  (58, 'user-agent', ''),
  (59, 'vary', ''),
  (60, 'via', ''),
  (61, 'www-authenticate', '');

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

create view edgerun_standards_fact_summary as
select 'standards_source' as fact_kind, count(*) as fact_count from edgerun_standards_source
union all select 'protocol', count(*) from edgerun_protocol_fact
union all select 'protocol_dependency', count(*) from edgerun_protocol_dependency_fact
union all select 'protocol_standard', count(*) from edgerun_protocol_standard_fact
union all select 'protocol_behavior', count(*) from edgerun_protocol_behavior_fact
union all select 'protocol_environment', count(*) from edgerun_protocol_environment_fact
union all select 'definition', count(*) from edgerun_definition_fact
union all select 'definition_field', count(*) from edgerun_definition_field_fact
union all select 'definition_variant', count(*) from edgerun_definition_variant_fact
union all select 'clause', count(*) from edgerun_clause_fact
union all select 'corpus_case', count(*) from edgerun_corpus_case_fact
union all select 'corpus_expectation', count(*) from edgerun_corpus_expectation_fact
union all select 'hpack_static_table', count(*) from hpack_static_table_fact
union all select 'hpack_interop_case', count(*) from hpack_interop_case_fact
union all select 'quic_varint_rule', count(*) from quic_varint_rule_fact
union all select 'quic_varint_example', count(*) from quic_varint_example_fact;

create view edgerun_standards_lookup_proofs as
select 'hpack_index_2' as proof_name, header_name || ':' || header_value as proof_value
from hpack_static_table_fact where hpack_index = 2
union all
select 'hpack_index_4', header_name || ':' || header_value
from hpack_static_table_fact where hpack_index = 4
union all
select 'tftp_valid_ack_all_match', cast(min(matches_expectation) as text)
from edgerun_tftp_corpus_proof where case_name = 'valid-ack'
union all
select 'quic_varint_64', actual_hex
from quic_varint_materialized_examples where value = 64;

create view edgerun_standards_gap_summary as
select 'protocol_without_definition' as gap_kind,
       protocol.id as subject,
       1 as gap_count
from edgerun_protocol_fact protocol
left join edgerun_definition_fact definition on definition.id like protocol.id || '%'
where definition.definition_id is null
union all
select 'behavior_without_executable_clause',
       protocol.id || ':' || behavior.behavior_name,
       1
from edgerun_protocol_behavior_fact behavior
join edgerun_protocol_fact protocol using (protocol_id)
left join edgerun_clause_fact clause on clause.subject like protocol.id || '%'
where clause.clause_id is null
union all
select 'source_unparsed_to_normalized_rows',
       namespace,
       1
from edgerun_standards_source
where namespace like 'standards.local.%'
  and format in ('toml', 'hex', 'json')
  and path not like '%/protocols/%'
  and path not like '%/definitions/udp.toml'
  and path not like '%/definitions/tftp.toml'
  and path not like '%/clauses/udp.toml'
  and path not like '%/clauses/tftp.toml'
  and path not like '%/corpus/tftp/%';

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

create view sql_toml_assignment as
select line.source_id,
       row_number() over (partition by line.source_id order by line.line_no) as assignment_id,
       line.line_no,
       (select scope.scope_path
        from sql_toml_scope_event scope
        where scope.source_id = line.source_id and scope.line_no < line.line_no
        order by scope.line_no desc
        limit 1) as scope_path,
       (select scope.scope_kind
        from sql_toml_scope_event scope
        where scope.source_id = line.source_id and scope.line_no < line.line_no
        order by scope.line_no desc
        limit 1) as scope_kind,
       (select scope.scope_instance
        from sql_toml_scope_event scope
        where scope.source_id = line.source_id and scope.line_no < line.line_no
        order by scope.line_no desc
        limit 1) as scope_instance,
       coalesce((select parent.scope_path
                 from sql_toml_scope_event parent
                 where parent.source_id = line.source_id
                   and parent.scope_kind = 'array_table'
                   and parent.line_no < line.line_no
                 order by parent.line_no desc
                 limit 1), '') as parent_array_path,
       coalesce((select parent.scope_instance
                 from sql_toml_scope_event parent
                 where parent.source_id = line.source_id
                   and parent.scope_kind = 'array_table'
                   and parent.line_no < line.line_no
                 order by parent.line_no desc
                 limit 1), 0) as parent_array_instance,
       trim(substr(line.text, 1, instr(line.text, '=') - 1)) as key,
       trim(substr(line.text, instr(line.text, '=') + 1)) as raw_value,
       line.raw_text
from sql_toml_line line
where line.line_kind = 'assignment';

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
from sql_toml_assignment assignment
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
from sql_toml_value
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
from sql_toml_value value
join edgerun_standards_source source using (source_id)
where value.value_kind = 'unknown';

create view toml_derived_definition_fact as
select source.source_id,
       max(case when value.scope_path = '' and value.key = 'id' then value.string_value end) as id,
       max(case when value.scope_path = '' and value.key = 'kind' then value.string_value end) as kind,
       max(case when value.scope_path = '' and value.key = 'standard' then value.string_value end) as standard,
       max(case when value.scope_path = '' and value.key = 'section' then value.string_value end) as section
from edgerun_standards_source source
join sql_toml_value value using (source_id)
where source.path like '%/standards/definitions/%.toml'
group by source.source_id;

create view toml_derived_definition_field_fact as
select definition.id as definition_id,
       value.scope_instance as field_order,
       max(case when value.key = 'name' then value.string_value end) as name,
       max(case when value.key = 'type' then value.string_value end) as field_type,
       coalesce(max(case when value.key = 'length' then value.string_value end), '') as length_expr,
       coalesce(max(case when value.key = 'constraint' then value.string_value end), '') as constraint_expr
from sql_toml_value value
join toml_derived_definition_fact definition using (source_id)
where value.scope_path = 'field'
group by definition.id, value.scope_instance;

create view toml_derived_definition_variant_fact as
select definition.id as definition_id,
       max(case when value.key = 'name' then value.string_value end) as variant_name,
       max(case when value.key = 'tag_field' then value.string_value end) as tag_field,
       max(case when value.key = 'tag' then value.int_value end) as tag_value
from sql_toml_value value
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
join sql_toml_value clause on clause.source_id = source.source_id
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
join sql_toml_value value using (source_id)
where source.path like '%/standards/corpus/%/cases.toml'
  and value.scope_path = 'case'
group by source.source_id, value.scope_instance;

create table standards_fact_rule (
  rule_id integer primary key,
  rule_name text not null unique,
  input_fact_kind text not null,
  output_fact_kind text not null,
  description text not null
);

insert into standards_fact_rule(rule_id, rule_name, input_fact_kind, output_fact_kind, description) values
  (1, 'observe_toml_line', 'source_bytes', 'source_line_observation', 'Split imported source bytes into deterministic line observations.'),
  (2, 'classify_toml_line_shape', 'source_line_observation', 'line_shape_classification', 'Classify observed source lines by explicit byte/character facts.'),
  (3, 'classify_toml_scalar_value', 'assignment_observation', 'typed_value_fact', 'Classify observed assignment values by explicit value-shape facts.'),
  (4, 'derive_corpus_case_fact', 'typed_value_fact', 'corpus_case_fact', 'Derive corpus case facts from classified case-scope values.'),
  (5, 'derive_corpus_expectation_fact', 'array_pair_observation', 'corpus_expectation_fact', 'Derive corpus expectation facts from classified expectation pair observations.');

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
from sql_toml_value value
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
from sql_toml_multiline_array_pair_item pair
join edgerun_standards_source source using (source_id);

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
from sql_toml_value value
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
join sql_toml_multiline_array_pair_item pair
  on pair.source_id = case_fact.source_id
 and pair.scope_path = 'case'
 and pair.scope_instance = case_fact.case_instance
 and pair.key = 'expect'
join edgerun_standards_source source on source.source_id = case_fact.source_id
join standards_fact_rule rule on rule.rule_name = 'derive_corpus_expectation_fact';

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
join sql_toml_multiline_array_pair_item pair
  on pair.source_id = case_fact.source_id
 and pair.scope_path = 'case'
 and pair.scope_instance = case_fact.case_instance
 and pair.key = 'expect'
join edgerun_standards_source source on source.source_id = case_fact.source_id
join standards_fact_rule rule on rule.rule_name = 'derive_corpus_expectation_fact';

create view standards_fact_gap as
select application.rule_name as gap_kind,
       application.namespace,
       application.line_no,
       observed.evidence
from standards_fact_rule_application application
left join standards_observed_fact observed on observed.fact_id = application.input_fact_id
where application.status = 'gap';

create view toml_derived_corpus_expectation_fact as
select subject as corpus_name,
       substr(predicate, 1, instr(predicate, ':') - 1) as case_name,
       substr(predicate, instr(predicate, ':') + 1) as clause_name,
       object as expected_result
from standards_derived_fact
where fact_kind = 'corpus_expectation_fact';

create view toml_derived_standards_comparison as
select 'definition' as fact_kind,
       curated.id as subject,
       case when derived.id is not null
             and curated.kind = derived.kind
             and curated.standard = derived.standard
             and curated.section = derived.section then 1 else 0 end as matches_curated
from edgerun_definition_fact curated
left join toml_derived_definition_fact derived on derived.id = curated.id
union all
select 'definition_field', curated.id || ':' || curated_field.name,
       case when derived.name is not null
             and curated_field.field_type = derived.field_type
             and curated_field.length_expr = derived.length_expr
             and curated_field.constraint_expr = derived.constraint_expr then 1 else 0 end
from edgerun_definition_field_fact curated_field
join edgerun_definition_fact curated using (definition_id)
left join toml_derived_definition_field_fact derived
  on derived.definition_id = curated.id
 and derived.field_order = curated_field.field_order
union all
select 'definition_variant', curated.id || ':' || curated_variant.variant_name,
       case when derived.variant_name is not null
             and curated_variant.tag_field = derived.tag_field
             and curated_variant.tag_value = derived.tag_value then 1 else 0 end
from edgerun_definition_variant_fact curated_variant
join edgerun_definition_fact curated using (definition_id)
left join toml_derived_definition_variant_fact derived
  on derived.definition_id = curated.id
 and derived.variant_name = curated_variant.variant_name
union all
select 'clause', curated.id,
       case when derived.id is not null
             and curated.predicate_expr = derived.predicate_expr
             and curated.violation_code = derived.violation_code then 1 else 0 end
from edgerun_clause_fact curated
left join toml_derived_clause_fact derived on derived.id = curated.id
where curated.id != 'tftp-message-definition'
union all
select 'corpus_expectation', corpus_case.case_name || ':' || clause.id,
       case when derived.expected_result = expected.expected_result then 1 else 0 end
from edgerun_corpus_expectation_fact expected
join edgerun_corpus_case_fact corpus_case using (case_id)
join edgerun_clause_fact clause using (clause_id)
left join toml_derived_corpus_expectation_fact derived
  on derived.corpus_name = corpus_case.corpus_name
 and derived.case_name = corpus_case.case_name
 and derived.clause_name = clause.id;

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

create view engine_tftp_corpus_proof as
select corpus_name,
       case_name,
       clause_name,
       expected_result,
       actual_result,
       matches_expectation
from engine_corpus_proof
where corpus_name = 'tftp';

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
from standards_observed_fact
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
from standards_derived_fact
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

create view engine_derivation as
select application.application_id as derivation_id,
       'standards:' || application.rule_name as rule_key,
       application.input_fact_id,
       application.output_fact_id,
       application.status,
       application.namespace,
       application.line_no,
       application.rule_name || ':' || application.input_fact_id || '->' || application.output_fact_id as stable_key
from standards_fact_rule_application application
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
where matches_expectation = 0;

create view engine_conflict as
select fact_kind,
       subject,
       predicate,
       count(distinct object) as distinct_value_count,
       group_concat(distinct object) as values_seen
from engine_fact
where fact_kind in ('corpus_case_fact', 'corpus_expectation_fact', 'corpus_proof_fact')
group by fact_kind, subject, predicate
having count(distinct object) > 1;

create view engine_closure_step_0 as
select * from engine_fact where fact_status = 'observed';

create view engine_closure_step_1 as
select * from engine_fact where fact_status = 'derived';

create view engine_closure_step_2 as
select * from engine_fact where fact_status in ('validated', 'conflict');

create view engine_closure_final as
select * from engine_fact
where fact_status in ('observed', 'derived', 'validated');

create view engine_summary as
select 'fact:' || fact_kind as item_kind,
       fact_status as status,
       count(*) as item_count
from engine_fact
group by fact_kind, fact_status
union all
select 'derivation', status, count(*)
from engine_derivation
group by status
union all
select 'gap:' || gap_kind, gap_class, count(*)
from engine_gap
group by gap_kind, gap_class
union all
select 'conflict', fact_kind, count(*)
from engine_conflict
group by fact_kind;

create view engine_tftp_proof_summary as
select min(matches_expectation) as all_expectations_match,
       count(*) as expectation_count
from engine_tftp_corpus_proof;
