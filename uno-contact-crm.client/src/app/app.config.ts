import { registerLocaleData } from '@angular/common';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import localeEsMx from '@angular/common/locales/es-MX';
import {
  ApplicationConfig,
  LOCALE_ID,
  inject,
  provideAppInitializer,
  provideBrowserGlobalErrorListeners,
} from '@angular/core';
import { provideRouter, withComponentInputBinding } from '@angular/router';
import { routes } from './app.routes';
import { erroresInterceptor } from './core/http/errores.interceptor';
import { SesionService } from './core/sesion/sesion.service';

registerLocaleData(localeEsMx);

export const appConfig: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),
    provideRouter(routes, withComponentInputBinding()),
    provideHttpClient(withInterceptors([erroresInterceptor])),
    { provide: LOCALE_ID, useValue: 'es-MX' },
    // La sesión (perfiles y menú) se carga antes de resolver las rutas.
    provideAppInitializer(() => inject(SesionService).cargar()),
  ],
};
