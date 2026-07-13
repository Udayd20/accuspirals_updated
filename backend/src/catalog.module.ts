import { Module, Controller, Get, Injectable } from '@nestjs/common';
import { TypeOrmModule, InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ToolFamily, ToolSubtype, SpecFieldDef } from './entities';

@Injectable()
export class CatalogService {
  constructor(
    @InjectRepository(ToolFamily) private fam: Repository<ToolFamily>,
    @InjectRepository(ToolSubtype) private sub: Repository<ToolSubtype>,
    @InjectRepository(SpecFieldDef) private spec: Repository<SpecFieldDef>,
  ) {}

  // Returns the full taxonomy + dynamic form definitions the frontends use
  // to build the "Add Tool" screen (fields load by family / subtype).
  async families() {
    const fams = await this.fam.find();
    const subs = await this.sub.find();
    const specs = await this.spec.find({ order: { sort_order: 'ASC' } });
    return fams.map((f) => ({
      id: f.id,
      name: f.name,
      prefix: f.id_prefix,
      tracking: f.tracking,
      subtypes: subs.filter((s) => s.family_id === f.id).map((s) => s.name),
      fields: specs
        .filter((sp) => sp.family_id === f.id && !sp.subtype_id)
        .map((sp) => ({ label: sp.label, type: sp.input_type, unit: sp.unit, options: sp.options })),
      subFields: subs
        .filter((s) => s.family_id === f.id)
        .reduce((acc, s) => {
          const fs = specs.filter((sp) => sp.subtype_id === s.id);
          if (fs.length)
            acc[s.name] = fs.map((sp) => ({ label: sp.label, type: sp.input_type, unit: sp.unit, options: sp.options }));
          return acc;
        }, {} as Record<string, any>),
    }));
  }
}

@Controller('families')
export class CatalogController {
  constructor(private svc: CatalogService) {}
  @Get() list() { return this.svc.families(); }
}

@Module({
  imports: [TypeOrmModule.forFeature([ToolFamily, ToolSubtype, SpecFieldDef])],
  controllers: [CatalogController],
  providers: [CatalogService],
  exports: [CatalogService],
})
export class CatalogModule {}
