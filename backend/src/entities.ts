import { Entity, PrimaryGeneratedColumn, PrimaryColumn, Column } from 'typeorm';

@Entity('tool_family')
export class ToolFamily {
  @PrimaryGeneratedColumn() id: number;
  @Column() name: string;
  @Column() id_prefix: string;
  @Column({ default: 'individual' }) tracking: string;
  @Column({ default: 0 }) seq: number;
}

@Entity('tool_subtype')
export class ToolSubtype {
  @PrimaryGeneratedColumn() id: number;
  @Column() family_id: number;
  @Column() name: string;
}

@Entity('spec_field_def')
export class SpecFieldDef {
  @PrimaryGeneratedColumn() id: number;
  @Column() family_id: number;
  @Column({ nullable: true }) subtype_id: number;
  @Column() label: string;
  @Column({ default: 'text' }) input_type: string;
  @Column({ nullable: true }) unit: string;
  @Column({ type: 'jsonb', nullable: true }) options: string[];
  @Column({ default: false }) mandatory: boolean;
  @Column({ default: 0 }) sort_order: number;
}

@Entity('tool')
export class Tool {
  @PrimaryGeneratedColumn() id: number;
  @Column() code: string;
  @Column({ nullable: true }) family_id: number;
  @Column({ nullable: true }) subtype_id: number;
  @Column() category: string;
  @Column() name: string;
  @Column({ nullable: true }) manufacturer: string;
  @Column({ nullable: true }) supplier_code: string;
  @Column({ nullable: true }) material: string;
  @Column('numeric', { default: 0 }) cost: number;
  @Column({ default: 'AVAILABLE' }) status: string;
  @Column({ nullable: true }) location: string;
  @Column({ nullable: true }) recv_unit: string;
  @Column({ nullable: true }) unit: string;
  @Column({ nullable: true }) issued_to: string;
  @Column({ nullable: true }) machine: string;
  @Column({ nullable: true }) work_order: string;
  @Column({ type: 'date', nullable: true }) expected_return: string;
  @Column({ nullable: true }) issued_by: string;
  @Column({ type: 'date', nullable: true }) issued_date: string;
  @Column({ type: 'timestamptz', nullable: true }) issued_at: Date;
  @Column({ nullable: true }) issued_from: string;
  @Column({ type: 'timestamptz', nullable: true }) returned_at: Date;
  @Column({ default: 'Good' }) condition: string;
  @Column('numeric', { default: 0 }) regrind_cost: number;
  @Column({ default: 0 }) times_issued: number;
  @Column({ default: 0 }) times_reground: number;
  @Column({ type: 'jsonb', default: {} }) spec: Record<string, string>;
  @Column({ type: 'timestamptz', default: () => 'now()' }) created_at: Date;
}

@Entity('stock')
export class Stock {
  @PrimaryGeneratedColumn() id: number;
  @Column() category: string;
  @Column() name: string;
  @Column({ default: 0 }) qty: number;
  @Column('numeric', { default: 0 }) cost: number;
  @Column({ nullable: true }) location: string;
}

@Entity('gate_entry')
export class GateEntry {
  @PrimaryGeneratedColumn() id: number;
  @Column() gate_no: string;
  @Column({ nullable: true }) supplier: string;
  @Column({ nullable: true }) received_by: string;
  @Column({ nullable: true }) invoice_no: string;
  @Column({ type: 'date', nullable: true }) invoice_date: string;
  @Column('numeric', { default: 0 }) invoice_value: number;
  @Column({ type: 'text', nullable: true }) invoice_photo: string;
  @Column({ nullable: true }) unit: string;
  @Column({ type: 'timestamptz', default: () => 'now()' }) created_at: Date;
}

@Entity('gate_line')
export class GateLine {
  @PrimaryGeneratedColumn() id: number;
  @Column() gate_id: number;
  @Column({ nullable: true }) category: string;
  @Column({ nullable: true }) name: string;
  @Column({ nullable: true }) manufacturer: string;
  @Column({ default: 1 }) qty: number;
  @Column('numeric', { default: 0 }) cost: number;
  @Column({ nullable: true }) condition: string;
  @Column({ nullable: true }) gate_qc: string;
}

@Entity('qc_queue')
export class QcQueue {
  @PrimaryGeneratedColumn() id: number;
  @Column({ nullable: true }) gate_no: string;
  @Column({ nullable: true }) category: string;
  @Column() name: string;
  @Column({ nullable: true }) manufacturer: string;
  @Column({ default: 1 }) qty: number;
  @Column('numeric', { default: 0 }) cost: number;
  @Column({ nullable: true }) condition: string;
  @Column({ type: 'jsonb', default: {} }) spec: Record<string, string>;
  @Column({ nullable: true }) supplier: string;
  @Column({ nullable: true }) unit: string;
}

@Entity('event')
export class EventLog {
  @PrimaryGeneratedColumn() id: number;
  @Column({ nullable: true }) tool_code: string;
  @Column() type: string;
  @Column() text: string;
  @Column({ type: 'timestamptz', default: () => 'now()' }) ts: Date;
}

@Entity('master_data')
export class MasterData {
  @PrimaryGeneratedColumn() id: number;
  @Column() kind: string;
  @Column() value: string;
}

@Entity('app_user')
export class AppUser {
  @PrimaryGeneratedColumn() id: number;
  @Column() user_id: string;
  @Column({ nullable: true }) name: string;
  @Column() role: string;
  @Column() scope: string;
  @Column({ nullable: true }) password_hash: string;
}

@Entity('role_perm')
export class RolePerm {
  @PrimaryColumn() role: string;
  @Column({ type: 'jsonb', default: [] }) screens: string[];
}
