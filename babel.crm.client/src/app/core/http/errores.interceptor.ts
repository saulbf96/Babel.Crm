import { HttpErrorResponse, HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Router } from '@angular/router';
import { catchError, throwError } from 'rxjs';
import { SesionService } from '../sesion/sesion.service';

const MENSAJES: Record<number, string> = {
  0: 'No hay comunicación con el servidor.',
  403: 'No tienes permiso para realizar esta acción.',
  404: 'No se encontró la información solicitada.',
  429: 'Demasiados intentos. Espera un minuto y vuelve a intentar.',
};

/**
 * - Agrega el encabezado anti-CSRF que exige la API en las peticiones que modifican datos.
 * - Si la sesión vence (401), regresa al login.
 * - Muestra un aviso entendible; el detalle técnico se queda en la bitácora del servidor.
 */
export const erroresInterceptor: HttpInterceptorFn = (req, next) => {
  const avisos = inject(MatSnackBar);
  const router = inject(Router);
  const sesion = inject(SesionService);

  const peticion = req.url.startsWith('/api') ? req.clone({ setHeaders: { 'X-Babel-Crm': '1' } }) : req;

  return next(peticion).pipe(
    catchError((error: unknown) => {
      if (error instanceof HttpErrorResponse) {
        const esAcceso = req.url.startsWith('/api/acceso') || req.url === '/api/sesion';
        if (error.status === 401 && !esAcceso) {
          sesion.limpiar();
          avisos.open('Tu sesión terminó. Vuelve a iniciar sesión.', 'Cerrar', { duration: 6000 });
          void router.navigateByUrl('/acceso');
        } else if (!esAcceso) {
          const mensaje = MENSAJES[error.status] ?? 'Ocurrió un error. Intenta de nuevo o repórtalo a sistemas.';
          avisos.open(mensaje, 'Cerrar', { duration: 6000 });
        }
      }
      return throwError(() => error);
    }),
  );
};
