import { HttpClient } from '@angular/common/http';
import { Injectable, computed, inject, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { Perfil, ResultadoInicioSesion, Sesion } from './sesion.models';

/** Sesión del usuario de BABEL. La cookie la maneja el servidor (HttpOnly); aquí solo se leen sus datos. */
@Injectable({ providedIn: 'root' })
export class SesionService {
  private readonly http = inject(HttpClient);
  private readonly _sesion = signal<Sesion | null>(null);

  readonly sesion = this._sesion.asReadonly();
  readonly autenticado = computed(() => this._sesion() !== null);
  readonly menu = computed(() => this._sesion()?.menu ?? []);
  readonly usuario = computed(() => this._sesion()?.usuario ?? '');

  /** Recupera la sesión vigente (si la cookie sigue activa). Sin sesión, queda en null. */
  async cargar(): Promise<void> {
    try {
      this._sesion.set(await firstValueFrom(this.http.get<Sesion>('/api/sesion')));
    } catch {
      this._sesion.set(null);
    }
  }

  async iniciarSesion(usuario: string, contrasena: string): Promise<ResultadoInicioSesion> {
    const resultado = await firstValueFrom(
      this.http.post<ResultadoInicioSesion>('/api/acceso/iniciar', { usuario, contrasena }),
    );
    await this.cargar();
    return resultado;
  }

  async cerrarSesion(): Promise<void> {
    try {
      await firstValueFrom(this.http.post('/api/acceso/cerrar', {}));
    } finally {
      this._sesion.set(null);
    }
  }

  /** Se usa cuando el servidor responde 401 (sesión vencida). */
  limpiar(): void {
    this._sesion.set(null);
  }

  tienePerfil(perfil: Perfil): boolean {
    return this._sesion()?.perfiles.includes(perfil) ?? false;
  }
}
