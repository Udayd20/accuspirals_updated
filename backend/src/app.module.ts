import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import * as E from './entities';
import { CatalogModule } from './catalog.module';
import { ToolsModule } from './tools.module';
import { ReceivingModule } from './receiving.module';
import { AdminModule } from './admin.module';
import { DashboardModule } from './dashboard.module';
import { AuthModule } from './auth.module';

@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: process.env.DB_HOST || 'localhost',
      port: +(process.env.DB_PORT || 5432),
      username: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASS || 'postgres',
      database: process.env.DB_NAME || 'accuspirals',
      entities: [
        E.ToolFamily, E.ToolSubtype, E.SpecFieldDef, E.Tool, E.Stock,
        E.GateEntry, E.QcQueue, E.EventLog, E.MasterData, E.AppUser, E.RolePerm,
      ],
      synchronize: false, // schema managed by db/schema.sql
    }),
    AuthModule, CatalogModule, ToolsModule, ReceivingModule, AdminModule, DashboardModule,
  ],
})
export class AppModule {}
