import { Module, Controller, Get, Post, Delete, Param, Query, Body, Injectable } from '@nestjs/common';
import { TypeOrmModule, InjectRepository } from '@nestjs/typeorm';
import { Repository, ILike } from 'typeorm';
import { Tool, Stock, EventLog, ToolFamily } from './entities';

@Injectable()
export class ToolsService {
  constructor(
    @InjectRepository(Tool) private tools: Repository<Tool>,
    @InjectRepository(Stock) private stock: Repository<Stock>,
    @InjectRepository(EventLog) private events: Repository<EventLog>,
    @InjectRepository(ToolFamily) private fam: Repository<ToolFamily>,
  ) {}

  private log(code: string, type: string, text: string) {
    return this.events.save(this.events.create({ tool_code: code, type, text }));
  }

  async list(q?: string, status?: string, category?: string) {
    const where: any = {};
    if (status) where.status = status;
    if (category) where.category = ILike(`%${category}%`);
    let items = await this.tools.find({ where, order: { created_at: 'DESC' } });
    if (q) {
      const s = q.toLowerCase();
      items = items.filter((t) =>
        `${t.code} ${t.name} ${t.category} ${t.material} ${t.manufacturer}`.toLowerCase().includes(s),
      );
    }
    const stock = await this.stock.find();
    return { tools: items, stock };
  }

  async detail(code: string) {
    const tool = await this.tools.findOne({ where: { code } });
    const timeline = await this.events.find({ where: { tool_code: code }, order: { ts: 'DESC' } });
    return { tool, timeline };
  }

  // generate next code for a family prefix (atomic-ish; wrap in txn in prod)
  private async nextCode(familyName: string): Promise<{ code: string; family: ToolFamily }> {
    const family = await this.fam.findOne({ where: { name: familyName.split(' ▸ ')[0] } });
    const prefix = family?.id_prefix || 'GEN';
    const seq = (family?.seq || 0) + 1;
    if (family) { family.seq = seq; await this.fam.save(family); }
    return { code: `${prefix}-${String(seq).padStart(6, '0')}`, family };
  }

  async add(dto: any) {
    const { code, family } = await this.nextCode(dto.family);
    const category = `${dto.family} ▸ ${dto.subtype}`;
    const tool = this.tools.create({
      code, category, name: dto.name, manufacturer: dto.supplier, supplier_code: dto.supplierCode,
      material: dto.material, cost: dto.cost || 0, status: 'AVAILABLE', location: dto.location || 'Unassigned',
      family_id: family?.id, spec: dto.spec || {},
    });
    await this.tools.save(tool);
    await this.log(code, 'accept', `Added via master spec form (${category})`);
    return tool;
  }

  async issue(code: string, dto: any) {
    const t = await this.tools.findOne({ where: { code } });
    if (!t || t.status !== 'AVAILABLE') return { error: 'Tool not available' };
    Object.assign(t, {
      status: 'ISSUED', issued_to: dto.employee, unit: dto.unit, machine: dto.machine,
      work_order: dto.workOrder || '—', expected_return: dto.expectedReturn || null,
      issued_from: t.location && t.location !== '—' ? t.location : (t.location || null), location: '—',
      issued_by: dto.issuedBy || null, issued_date: dto.issueDate || null, issued_at: new Date(), returned_at: null,
      times_issued: t.times_issued + 1,
    });
    await this.tools.save(t);
    await this.log(code, 'issue', `Issued to ${dto.employee} · ${dto.machine} · ${dto.unit}`);
    return t;
  }

  async ret(code: string, dto: any) {
    const t = await this.tools.findOne({ where: { code } });
    if (!t || t.status !== 'ISSUED') return { error: 'Tool not issued' };
    await this.log(code, 'return', `Returned by ${dto.returnedBy || t.issued_to} · received by ${dto.receivedBy || '—'} · condition: ${dto.condition}${dto.damage ? ' · damage: ' + dto.damage : ''}`);
    const map: Record<string, [string, string]> = {
      reuse: ['AVAILABLE', 'Returned to available stock'],
      regrind: ['REGRINDING', 'Sent for regrinding'],
      repair: ['REPAIR', 'Sent for repair'],
      scrap: ['SCRAP', 'Scrapped — end of life'],
    };
    const [status, msg] = map[dto.decision] || map['reuse'];
    Object.assign(t, {
      status, condition: dto.condition, issued_to: '—', machine: '—', unit: '—', work_order: '—',
      expected_return: null, returned_at: new Date(), location: dto.decision === 'reuse' ? (dto.location || 'Unassigned') : (status === 'SCRAP' ? '—' : '@ vendor'),
    });
    await this.tools.save(t);
    await this.log(code, dto.decision, msg);
    return t;
  }

  async regrindList() {
    return this.tools.find({ where: [{ status: 'REGRINDING' }, { status: 'REPAIR' }] });
  }

  async regrindReceive(code: string, dto: any) {
    const pass = !!dto.pass;
    const t = await this.tools.findOne({ where: { code } });
    if (!t) return { error: 'not found' };
    if (pass) {
      const cost = Number(dto.cost) || 0;
      const spec: Record<string, string> = { ...(t.spec || {}) };
      if (dto.work) spec['Last service'] = String(dto.work);
      if (dto.wear) spec['Wear at last service'] = String(dto.wear);
      if (dto.stockRemoved) spec['Stock removed last regrind (mm)'] = String(dto.stockRemoved);
      if (dto.regrindsLeft !== undefined && dto.regrindsLeft !== '') spec['Regrinds remaining'] = String(dto.regrindsLeft);
      if (dto.vendor) spec['Last serviced by'] = String(dto.vendor);
      Object.assign(t, {
        status: 'AVAILABLE', location: dto.location || 'Rack G2 / Shelf 4', condition: dto.condition || 'Good',
        times_reground: t.times_reground + 1, regrind_cost: Number(t.regrind_cost) + cost, spec,
      });
      const bits = [dto.work ? `work: ${dto.work}` : null, cost ? `+₹${cost}` : null,
        (dto.regrindsLeft !== undefined && dto.regrindsLeft !== '') ? `${dto.regrindsLeft} regrinds left` : null,
        dto.inspector ? `QC ${dto.inspector}` : null].filter(Boolean).join(' · ');
      await this.log(code, 'regrind', `Back from service · QC pass${bits ? ' · ' + bits : ''}`);
    } else {
      Object.assign(t, { status: 'SCRAP', location: '—' });
      await this.log(code, 'scrap', `Service QC failed · scrapped${dto.wear ? ' (' + dto.wear + ')' : ''}`);
    }
    await this.tools.save(t);
    return t;
  }

  async remove(code: string) {
    await this.tools.delete({ code });
    await this.log(code, 'admin', 'Tool deleted');
    return { deleted: code };
  }
}

@Controller('tools')
export class ToolsController {
  constructor(private svc: ToolsService) {}
  @Get() list(@Query('q') q, @Query('status') status, @Query('category') category) {
    return this.svc.list(q, status, category);
  }
  @Get('regrind/jobs') regrind() { return this.svc.regrindList(); }
  @Get(':code') detail(@Param('code') code) { return this.svc.detail(code); }
  @Post() add(@Body() dto) { return this.svc.add(dto); }
  @Post(':code/issue') issue(@Param('code') code, @Body() dto) { return this.svc.issue(code, dto); }
  @Post(':code/return') ret(@Param('code') code, @Body() dto) { return this.svc.ret(code, dto); }
  @Post(':code/regrind/receive') recv(@Param('code') code, @Body() dto) { return this.svc.regrindReceive(code, dto); }
  @Delete(':code') remove(@Param('code') code) { return this.svc.remove(code); }
}

@Module({
  imports: [TypeOrmModule.forFeature([Tool, Stock, EventLog, ToolFamily])],
  controllers: [ToolsController],
  providers: [ToolsService],
})
export class ToolsModule {}
