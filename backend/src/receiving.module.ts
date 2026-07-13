import { Module, Controller, Get, Post, Param, Body, Injectable } from '@nestjs/common';
import { TypeOrmModule, InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { GateEntry, QcQueue, Tool, Stock, EventLog, ToolFamily } from './entities';

@Injectable()
export class ReceivingService {
  constructor(
    @InjectRepository(GateEntry) private gates: Repository<GateEntry>,
    @InjectRepository(QcQueue) private qc: Repository<QcQueue>,
    @InjectRepository(Tool) private tools: Repository<Tool>,
    @InjectRepository(Stock) private stock: Repository<Stock>,
    @InjectRepository(EventLog) private events: Repository<EventLog>,
    @InjectRepository(ToolFamily) private fam: Repository<ToolFamily>,
  ) {}
  private log(code, type, text) { return this.events.save(this.events.create({ tool_code: code, type, text })); }

  // create gate entry + push non-rejected lines into QC queue
  async gate(dto: any) {
    const count = await this.gates.count();
    const gate_no = `GE-2026-${418 + count}`;
    await this.gates.save(this.gates.create({ gate_no, supplier: dto.supplier, received_by: dto.receivedBy, invoice_no: dto.invoiceNo, invoice_date: dto.invoiceDate || null, invoice_value: dto.invoiceValue || 0, invoice_photo: dto.invoicePhoto || null }));
    let sent = 0, rej = 0;
    for (const l of dto.lines || []) {
      if (l.gate_qc === 'Reject') { rej++; await this.log('—', 'reject', `Rejected at gate: ${l.name} ×${l.qty}`); }
      else {
        await this.qc.save(this.qc.create({ gate_no, category: l.category, name: l.name,
          manufacturer: l.manufacturer, qty: l.qty, cost: l.cost, condition: l.condition, spec: l.spec || {}, supplier: dto.supplier || null }));
        sent++;
      }
    }
    await this.log('—', 'gate', `Gate entry ${gate_no} — ${sent} line(s) to inventory${rej ? `, ${rej} rejected` : ''}`);
    return { gate_no, sent, rejected: rej };
  }

  qcQueue() { return this.qc.find(); }

  async accept(id: number, dto: any) {
    const q = await this.qc.findOne({ where: { id } });
    if (!q) return { error: 'not found' };
    const accepted = dto.accepted ?? q.qty;
    const family = await this.fam.findOne({ where: { name: q.category.split(' ▸ ')[0] } });
    const created: string[] = [];
    if (family && family.tracking !== 'quantity') {
      for (let i = 0; i < accepted; i++) {
        family.seq += 1;
        const code = `${family.id_prefix}-${String(family.seq).padStart(6, '0')}`;
        await this.tools.save(this.tools.create({
          code, category: q.category, name: q.name, manufacturer: q.manufacturer, cost: q.cost,
          status: 'AVAILABLE', location: dto.location || 'Unassigned', family_id: family.id, spec: q.spec || {},
        }));
        await this.log(code, 'accept', `Inventory accepted · stored ${dto.location || 'Unassigned'}${dto.inspector ? ' · QC ' + dto.inspector : ''}`);
        created.push(code);
      }
      await this.fam.save(family);
    } else {
      const ex = await this.stock.findOne({ where: { name: q.name } });
      if (ex) { ex.qty += accepted; await this.stock.save(ex); }
      else await this.stock.save(this.stock.create({ category: q.category, name: q.name, qty: accepted, cost: q.cost, location: dto.location }));
      await this.log('—', 'accept', `Accepted ${accepted} × ${q.name} into stock`);
    }
    await this.qc.delete({ id });
    return { accepted, created };
  }

  async reject(id: number) {
    const q = await this.qc.findOne({ where: { id } });
    if (q) { await this.log('—', 'reject', `Inventory QC rejected: ${q.name}`); await this.qc.delete({ id }); }
    return { rejected: id };
  }

  async updateQc(id: number, dto: any) {
    const q = await this.qc.findOne({ where: { id } });
    if (!q) return { error: 'not found' };
    Object.assign(q, {
      category: dto.category ?? q.category, name: dto.name ?? q.name,
      manufacturer: dto.manufacturer ?? q.manufacturer, qty: dto.qty ?? q.qty,
      cost: dto.cost ?? q.cost, condition: dto.condition ?? q.condition, spec: dto.spec ?? q.spec,
    });
    await this.qc.save(q);
    await this.log('—', 'admin', `QC item edited: ${q.name}`);
    return q;
  }
}

@Controller()
export class ReceivingController {
  constructor(private svc: ReceivingService) {}
  @Post('gate') gate(@Body() dto) { return this.svc.gate(dto); }
  @Get('qc') qc() { return this.svc.qcQueue(); }
  @Post('qc/:id/accept') accept(@Param('id') id, @Body() dto) { return this.svc.accept(+id, dto); }
  @Post('qc/:id/reject') reject(@Param('id') id) { return this.svc.reject(+id); }
  @Post('qc/:id/update') updateQc(@Param('id') id, @Body() dto) { return this.svc.updateQc(+id, dto); }
}

@Module({
  imports: [TypeOrmModule.forFeature([GateEntry, QcQueue, Tool, Stock, EventLog, ToolFamily])],
  controllers: [ReceivingController],
  providers: [ReceivingService],
})
export class ReceivingModule {}
