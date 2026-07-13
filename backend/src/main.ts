import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module';
import { existsSync, readFileSync } from 'fs';
import { join } from 'path';

async function bootstrap() {
  // Optional HTTPS: if backend/certs/server.key + server.crt exist, serve over TLS.
  const certDir = join(process.cwd(), 'certs');
  const keyF = join(certDir, 'server.key');
  const crtF = join(certDir, 'server.crt');
  const useHttps = existsSync(keyF) && existsSync(crtF);
  const httpsOptions = useHttps ? { key: readFileSync(keyF), cert: readFileSync(crtF) } : undefined;

  const app = await NestFactory.create<NestExpressApplication>(
    AppModule,
    httpsOptions ? { httpsOptions } : {},
  );
  app.enableCors(); // allow Flutter / web clients
  app.setGlobalPrefix('api');

  // Serve the web app from the backend so it can be opened over the network
  // at http(s)://<this-machine>:3000/  (single origin — no mixed-content issues).
  const webDir = join(process.cwd(), '..', 'web');
  if (existsSync(webDir)) {
    app.useStaticAssets(webDir);
  }

  const port = process.env.PORT || 3000;
  await app.listen(port);
  const proto = useHttps ? 'https' : 'http';
  console.log(`ACCUSPIRALS API running on ${proto}://localhost:${port}/api`);
  if (existsSync(webDir)) {
    console.log(`ACCUSPIRALS web app served at ${proto}://localhost:${port}/`);
  }
  if (!useHttps) {
    console.log('[tls] Running over HTTP. To enable HTTPS, run ./gen-cert.sh in backend/ and restart.');
  }
}
bootstrap();
