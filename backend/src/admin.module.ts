import { Module, Controller, Get, Post, Delete, Param, Body, Injectable } from '@nestjs/common';
import { TypeOrmModule, InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { MasterData, AppUser, ToolFamily, ToolSubtype, EventLog, SpecFieldDef, RolePerm } from './entities';
import { hashPw, Roles } from './auth.module';

@Injectable()
export class AdminService {
  constructor(
    @InjectRepository(MasterData) private md: Repository<MasterData>,
    @InjectRepository(AppUser) private users: Repository<AppUser>,
    @InjectRepository(ToolFamily) private fam: Repository<ToolFamily>,
    @InjectRepository(ToolSubtype) private sub: Repository<ToolSubtype>,
    @InjectRepository(EventLog) private events: Repository<EventLog>,
    @InjectRepository(SpecFieldDef) private specs: Repository<SpecFieldDef>,
    @InjectRepository(RolePerm) private perms: Repository<RolePerm>,
  ) {}
  private log(t, x) { return this.events.save(this.events.create({ tool_code: '—', type: 'admin', text: x })); }

  master(kind?: string) { return kind ? this.md.find({ where: { kind } }) : this.md.find(); }
  async addMaster(kind: string, value: string) {
    const m = await this.md.save(this.md.create({ kind, value }));
    await this.log('admin', `${kind} added: ${value}`); return m;
  }
  async delMaster(id: number) { await this.md.delete({ id }); return { deleted: id }; }

  async listUsers() { const us = await this.users.find(); return us.map(u => ({ id: u.id, user_id: u.user_id, name: u.name, role: u.role, scope: u.scope, hasPassword: !!u.password_hash })); }
  async addUser(dto: any) {
    const u = await this.users.save(this.users.create({
      user_id: dto.userId, name: dto.name, role: dto.role, scope: dto.scope || '',
      password_hash: hashPw(dto.password || 'accuspirals'),
    }));
    await this.log('admin', `User added: ${dto.userId} (${dto.role})`);
    return { id: u.id, user_id: u.user_id, name: u.name, role: u.role };
  }
  async resetPassword(id: number, password: string) {
    const u = await this.users.findOne({ where: { id } });
    if (!u) return { error: 'not found' };
    u.password_hash = hashPw(password || 'accuspirals');
    await this.users.save(u);
    await this.log('admin', `Password reset: ${u.user_id}`);
    return { ok: true };
  }
  async delUser(id: number) { await this.users.delete({ id }); return { deleted: id }; }

  // add a family or a subtype under an existing family
  async addCategory(dto: any) {
    if (dto.parent) {
      const family = await this.fam.findOne({ where: { name: dto.parent } });
      if (!family) return { error: 'parent family not found' };
      const s = await this.sub.save(this.sub.create({ family_id: family.id, name: dto.name }));
      await this.log('admin', `Subtype added: ${dto.parent} ▸ ${dto.name}`); return s;
    }
    const prefix = dto.prefix || dto.name.split(' ').map((w) => w[0]).join('').toUpperCase().slice(0, 4);
    const f = await this.fam.save(this.fam.create({ name: dto.name, id_prefix: prefix, tracking: dto.tracking || 'individual', seq: 0 }));
    await this.log('admin', `Family added: ${dto.name}`); return f;
  }

  // ---- specification field definitions (admin-managed dynamic fields) ----
  private async resolveIds(familyName: string, subtypeName?: string) {
    const family = await this.fam.findOne({ where: { name: familyName } });
    if (!family) return { error: 'family not found' } as any;
    let subtype_id: number | null = null;
    if (subtypeName) {
      const st = await this.sub.findOne({ where: { family_id: family.id, name: subtypeName } });
      if (!st) return { error: 'subtype not found' } as any;
      subtype_id = st.id;
    }
    return { family_id: family.id, subtype_id };
  }
  async addSpecField(dto: any) {
    const ids = await this.resolveIds(dto.familyName, dto.subtypeName);
    if ((ids as any).error) return ids;
    const { family_id, subtype_id } = ids as any;
    const scope = await this.specs.find({ where: { family_id, subtype_id: subtype_id ?? null } });
    const sort_order = scope.reduce((m, r) => Math.max(m, r.sort_order), 0) + 1;
    const opts = Array.isArray(dto.options) && dto.options.length ? dto.options : null;
    const row = await this.specs.save(this.specs.create({
      family_id, subtype_id, label: dto.label, input_type: dto.type || 'text',
      unit: dto.unit || null, options: opts, mandatory: !!dto.mandatory, sort_order,
    }));
    await this.log('admin', `Spec field added: ${dto.familyName}${dto.subtypeName ? ' \u25b8 ' + dto.subtypeName : ''} / ${dto.label}`);
    return row;
  }
  async updateSpecField(id: number, dto: any) {
    const row = await this.specs.findOne({ where: { id } });
    if (!row) return { error: 'not found' };
    if (dto.label !== undefined) row.label = dto.label;
    if (dto.type !== undefined) row.input_type = dto.type;
    if (dto.unit !== undefined) row.unit = dto.unit || null;
    if (dto.options !== undefined) row.options = Array.isArray(dto.options) && dto.options.length ? dto.options : null;
    if (dto.mandatory !== undefined) row.mandatory = !!dto.mandatory;
    if (dto.sort_order !== undefined) row.sort_order = dto.sort_order;
    await this.specs.save(row);
    return { ok: true };
  }
  async delSpecField(id: number) { await this.specs.delete({ id }); return { deleted: id }; }
  async listPermissions() { return this.perms.find(); }
  async setPermissions(role: string, screens: string[]) {
    let row = await this.perms.findOne({ where: { role } });
    if (!row) row = this.perms.create({ role, screens: [] });
    row.screens = Array.isArray(screens) ? screens : [];
    await this.perms.save(row);
    await this.log('admin', `Permissions updated: ${role} → ${row.screens.join(', ')}`);
    return { ok: true, role, screens: row.screens };
  }
  async listSpecFields() {
    const rows = await this.specs.find({ order: { sort_order: 'ASC' } });
    const fams = await this.fam.find();
    const subs = await this.sub.find();
    return rows.map((r) => ({
      id: r.id,
      family: (fams.find((f) => f.id === r.family_id) || ({} as any)).name,
      subtype: r.subtype_id ? (subs.find((s) => s.id === r.subtype_id) || ({} as any)).name : null,
      label: r.label, type: r.input_type, unit: r.unit, options: r.options, sort: r.sort_order,
    }));
  }
}

@Controller('admin')
export class AdminController {
  constructor(private svc: AdminService) {}
  @Get('master') master(@Param() _p, @Body() _b) { return this.svc.master(); }
  @Get('master/:kind') masterKind(@Param('kind') kind) { return this.svc.master(kind); }
  @Roles('Admin') @Post('master') addMaster(@Body() dto) { return this.svc.addMaster(dto.kind, dto.value); }
  @Roles('Admin') @Delete('master/:id') delMaster(@Param('id') id) { return this.svc.delMaster(+id); }
  @Roles('Admin') @Get('users') users() { return this.svc.listUsers(); }
  @Roles('Admin') @Post('users') addUser(@Body() dto) { return this.svc.addUser(dto); }
  @Roles('Admin') @Post('users/:id/reset') reset(@Param('id') id, @Body() dto) { return this.svc.resetPassword(+id, dto.password); }
  @Roles('Admin') @Delete('users/:id') delUser(@Param('id') id) { return this.svc.delUser(+id); }
  @Roles('Admin') @Post('categories') addCat(@Body() dto) { return this.svc.addCategory(dto); }
  @Roles('Admin') @Get('permissions') perms() { return this.svc.listPermissions(); }
  @Roles('Admin') @Post('permissions') setPerms(@Body() dto) { return this.svc.setPermissions(dto.role, dto.screens); }
  @Roles('Admin') @Get('spec-fields') specFields() { return this.svc.listSpecFields(); }
  @Roles('Admin') @Post('spec-fields') addSpec(@Body() dto) { return this.svc.addSpecField(dto); }
  @Roles('Admin') @Post('spec-fields/:id/update') updSpec(@Param('id') id, @Body() dto) { return this.svc.updateSpecField(+id, dto); }
  @Roles('Admin') @Delete('spec-fields/:id') delSpec(@Param('id') id) { return this.svc.delSpecField(+id); }
}

@Module({
  imports: [TypeOrmModule.forFeature([MasterData, AppUser, ToolFamily, ToolSubtype, EventLog, SpecFieldDef, RolePerm])],
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
