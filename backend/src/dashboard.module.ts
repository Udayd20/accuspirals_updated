import { Module, Controller, Get, Injectable } from '@nestjs/common';
import { TypeOrmModule, InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Tool, Stock, QcQueue, EventLog } from './entities';

@Injectable()
export class DashboardService {
  constructor(
    @InjectRepository(Tool) private tools: Repository<Tool>,
    @InjectRepository(Stock) private stock: Repository<Stock>,
    @InjectRepository(QcQueue) private qc: Repository<QcQueue>,
    @InjectRepository(EventLog) private eventRepo: Repository<EventLog>,
  ) {}

  private async invValue() {
    const tools = await this.tools.find();
    const stock = await this.stock.find();
    const tv = tools.filter((t) => !['SCRAP', 'REJECTED'].includes(t.status)).reduce((a, t) => a + Number(t.cost), 0);
    const sv = stock.reduce((a, s) => a + s.qty * Number(s.cost), 0);
    return tv + sv;
  }

  async dashboard() {
    const tools = await this.tools.find();
    const by = (s: string) => tools.filter((t) => t.status === s).length;
    const recent = await this.eventRepo.find({ order: { ts: 'DESC' }, take: 6 });
    return {
      totalValue: await this.invValue(),
      toolsTracked: tools.length,
      available: by('AVAILABLE'),
      issued: by('ISSUED'),
      regrinding: by('REGRINDING') + by('REPAIR'),
      pendingQc: await this.qc.count(),
      scrapped: by('SCRAP'),
      lifecycleCost: tools.reduce((a, t) => a + Number(t.cost) + Number(t.regrind_cost), 0),
      recent,
    };
  }

  async reports() {
    const tools = await this.tools.find();
    const byCat: Record<string, number> = {};
    tools.filter((t) => t.status !== 'SCRAP').forEach((t) => { byCat[t.category] = (byCat[t.category] || 0) + Number(t.cost); });
    const byUnit: Record<string, number> = {};
    tools.filter((t) => t.status === 'ISSUED').forEach((t) => { byUnit[t.unit] = (byUnit[t.unit] || 0) + 1; });
    return {
      totalValue: await this.invValue(),
      lifecycleCost: tools.reduce((a, t) => a + Number(t.cost) + Number(t.regrind_cost), 0),
      scrapValue: tools.filter((t) => t.status === 'SCRAP').reduce((a, t) => a + Number(t.cost), 0),
      lifecycleByTool: tools.filter((t) => Number(t.regrind_cost) > 0)
        .map((t) => ({ code: t.code, name: t.name, cost: Number(t.cost), regrind: Number(t.regrind_cost), total: Number(t.cost) + Number(t.regrind_cost) })),
      valueByCategory: byCat,
      issuedByUnit: byUnit,
    };
  }

  events() { return this.eventRepo.find({ order: { ts: 'DESC' }, take: 50 }); }
}

@Controller()
export class DashboardController {
  constructor(private svc: DashboardService) {}
  @Get('dashboard') dash() { return this.svc.dashboard(); }
  @Get('reports') reports() { return this.svc.reports(); }
  @Get('events') events() { return this.svc.events(); }
}

@Module({
  imports: [TypeOrmModule.forFeature([Tool, Stock, QcQueue, EventLog])],
  controllers: [DashboardController],
  providers: [DashboardService],
})
export class DashboardModule {}
