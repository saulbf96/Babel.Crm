import { inject } from '@angular/core';
import { CanActivateFn, CanMatchFn, Router } from '@angular/router';
import { Perfil } from './sesion.models';
import { SesionService } from './sesion.service';

/** Exige sesión iniciada; si no hay, manda al login. */
export const sesionGuard: CanActivateFn = () =>
  inject(SesionService).autenticado() || inject(Router).parseUrl('/acceso');

/** Si el usuario debe cambiar su contraseña, lo fuerza a esa pantalla antes de usar el CRM. */
export const cambioContrasenaGuard: CanActivateFn = () => {
  const sesion = inject(SesionService);
  if (!sesion.autenticado()) return inject(Router).parseUrl('/acceso');
  return sesion.debeCambiarContrasena() ? inject(Router).parseUrl('/cambiar-contrasena') : true;
};

/** Protege la pantalla de cambio: solo se entra con sesión y con el cambio pendiente. */
export const requiereCambioGuard: CanActivateFn = () => {
  const sesion = inject(SesionService);
  if (!sesion.autenticado()) return inject(Router).parseUrl('/acceso');
  return sesion.debeCambiarContrasena() ? true : inject(Router).parseUrl('/inicio');
};

/**
 * Oculta rutas a quien no tiene el perfil. Es solo para la experiencia de usuario:
 * la autorización real la valida siempre la API.
 */
export function perfilGuard(...perfiles: Perfil[]): CanMatchFn {
  return () => {
    const sesion = inject(SesionService);
    return perfiles.some((perfil) => sesion.tienePerfil(perfil))
      || inject(Router).parseUrl('/acceso-denegado');
  };
}
