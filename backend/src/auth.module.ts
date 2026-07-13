import {
  Module, Injectable, CanActivate, ExecutionContext, SetMetadata,
  Controller, Post, Body, UnauthorizedException, ForbiddenException, OnModuleInit,
} from '@nestjs/common';
import { APP_GUARD, Reflector } from '@nestjs/core';
import { TypeOrmModule, InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AppUser, RolePerm } from './entities';
import { scryptSync, randomBytes, createHmac, timingSafeEqual } from 'crypto';
import { existsSync, readFileSync, writeFileSync } from 'fs';
import { join } from 'path';

// ---- config ----
const PLACEHOLDERS = ['change-me-to-a-long-random-string', 'accuspirals-dev-secret-change-me', ''];
let _secretCache: string | null = null;
function getSecret(): string {
  if (_secretCache) return _secretCache;
  const env = process.env.AUTH_SECRET;
  if (env && !PLACEHOLDERS.includes(env)) { _secretCache = env; return _secretCache; }
  // No real secret in env: generate one and persist it so tokens survive restarts.
  const file = join(process.cwd(), '.auth-secret');
  try {
    if (existsSync(file)) {
      const v = readFileSync(file, 'utf8').trim();
      if (v) { _secretCache = v; return _secretCache; }
    }
    const gen = randomBytes(48).toString('hex');
    writeFileSync(file, gen, { mode: 0o600 });
    console.warn('[auth] AUTH_SECRET not set — generated a persistent random secret at backend/.auth-secret');
    _secretCache = gen;
    return _secretCache;
  } catch (e) {
    _secretCache = env || 'accuspirals-dev-secret-change-me';
    return _secretCache;
  }
}
// Escape hatch: set AUTH_ENABLED=false in .env to disable all protection (recovery only).
const AUTH_ENABLED = (process.env.AUTH_ENABLED || 'true') !== 'false';
const TOKEN_TTL_MS = 12 * 60 * 60 * 1000; // 12 hours
const DEFAULT_PASSWORD = 'accuspirals';

// ---- decorators ----
export const Public = () => SetMetadata('isPublic', true);
export const Roles = (...roles: string[]) => SetMetadata('roles', roles);

// ---- password hashing (Node built-in scrypt; no external deps) ----
export function hashPw(pw: string): string {
  const salt = randomBytes(16).toString('hex');
  const h = scryptSync(pw, salt, 32).toString('hex');
  return `${salt}:${h}`;
}
export function verifyPw(pw: string, stored?: string): boolean {
  if (!stored) return false;
  const [salt, h] = stored.split(':');
  if (!salt || !h) return false;
  const hh = scryptSync(pw, salt, 32).toString('hex');
  try {
    return timingSafeEqual(Buffer.from(h, 'hex'), Buffer.from(hh, 'hex'));
  } catch {
    return false;
  }
}

// ---- signed tokens (HMAC-SHA256; JWT-like, no external deps) ----
function b64url(s: string) {
  return Buffer.from(s).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
function sign(data: string) {
  return createHmac('sha256', getSecret()).update(data).digest('base64')
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
export function signToken(payload: any): string {
  const body = { ...payload, exp: Date.now() + TOKEN_TTL_MS };
  const p = b64url(JSON.stringify(body));
  return `${p}.${sign(p)}`;
}
export function verifyToken(token: string): any | null {
  if (!token) return null;
  const [p, sig] = token.split('.');
  if (!p || !sig || sign(p) !== sig) return null;
  try {
    const body = JSON.parse(Buffer.from(p.replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString());
    if (!body.exp || Date.now() > body.exp) return null;
    return body;
  } catch {
    return null;
  }
}

@Injectable()
export class AuthService implements OnModuleInit {
  constructor(
    @InjectRepository(AppUser) private users: Repository<AppUser>,
    @InjectRepository(RolePerm) private perms: Repository<RolePerm>,
  ) {}

  // On startup, give any seeded user without a password the default one,
  // so the system is usable immediately (admin should reset afterwards).
  async onModuleInit() {
    const all = await this.users.find();
    for (const u of all) {
      if (!u.password_hash) {
        u.password_hash = hashPw(DEFAULT_PASSWORD);
        await this.users.save(u);
      }
    }
    // Warn (loudly) about any account still using the shipped default password.
    const refreshed = await this.users.find();
    const stillDefault = refreshed.filter((u) => verifyPw(DEFAULT_PASSWORD, u.password_hash)).map((u) => u.user_id);
    if (stillDefault.length) {
      console.warn(`[auth] SECURITY: these accounts still use the default password '${DEFAULT_PASSWORD}' — reset them in Admin \u25b8 Users: ${stillDefault.join(', ')}`);
    }
  }

  async login(userId: string, password: string) {
    const u = await this.users.findOne({ where: { user_id: userId } });
    if (!u || !verifyPw(password, u.password_hash)) {
      return { ok: false, error: 'Invalid employee ID or password' };
    }
    const perm = await this.perms.findOne({ where: { role: u.role } });
    const screens = perm && Array.isArray(perm.screens) ? perm.screens : null;
    const user = { id: u.user_id, name: u.name || u.user_id, role: u.role, screens };
    return { ok: true, token: signToken({ sub: u.user_id, name: user.name, role: u.role }), user };
  }
}

@Controller('auth')
export class AuthController {
  constructor(private svc: AuthService) {}
  @Public()
  @Post('login')
  login(@Body() dto) {
    return this.svc.login(dto?.userId, dto?.password);
  }
}

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(private reflector: Reflector) {}
  canActivate(ctx: ExecutionContext): boolean {
    if (!AUTH_ENABLED) return true; // recovery escape hatch
    const isPublic = this.reflector.getAllAndOverride<boolean>('isPublic', [ctx.getHandler(), ctx.getClass()]);
    if (isPublic) return true;
    const req = ctx.switchToHttp().getRequest();
    const auth = (req.headers['authorization'] as string) || '';
    const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
    const payload = verifyToken(token);
    if (!payload) throw new UnauthorizedException('Login required');
    req.user = payload;
    const roles = this.reflector.getAllAndOverride<string[]>('roles', [ctx.getHandler(), ctx.getClass()]);
    if (roles && roles.length && !roles.includes(payload.role)) {
      throw new ForbiddenException('Not allowed for your role');
    }
    return true;
  }
}

@Module({
  imports: [TypeOrmModule.forFeature([AppUser, RolePerm])],
  controllers: [AuthController],
  providers: [AuthService, { provide: APP_GUARD, useClass: AuthGuard }],
  exports: [AuthService],
})
export class AuthModule {}
