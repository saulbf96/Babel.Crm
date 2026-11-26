import { DestroyRef, Injectable, NgZone, computed, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Router } from '@angular/router';
import { firstValueFrom } from 'rxjs';
import { SesionService } from './sesion.service';

/** Minutos sin actividad antes de cerrar la sesión (igual que la cookie del servidor: ExpireTimeSpan = 30 min). */
export const MINUTOS_INACTIVIDAD = 30;
const LIMITE_MS = MINUTOS_INACTIVIDAD * 60_000;

/** Cada cuánto, si hay actividad, se avisa al servidor que el usuario sigue ahí (renueva la cookie). */
const MANTENER_VIVA_MS = 5 * 60_000;

/** Clave compartida entre pestañas: la actividad en cualquiera reinicia el reloj de todas. */
export const CLAVE_ULTIMA_ACTIVIDAD = 'unocontact.ultimaActividad';

const EVENTOS = ['mousemove', 'mousedown', 'keydown', 'wheel', 'touchstart', 'scroll'] as const;

/** Segundos que le quedan a la sesión (0 = ya venció). Función pura para poder probarla. */
export function segundosRestantes(ahoraMs: number, ultimaActividadMs: number, limiteMs = LIMITE_MS): number {
  return Math.max(0, Math.ceil((limiteMs - (ahoraMs - ultimaActividadMs)) / 1000));
}

/** "mm:ss" para mostrar en el reloj. */
export function formatoReloj(segundos: number): string {
  const s = Math.max(0, segundos);
  return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
}

/**
 * Cierre de sesión por inactividad (30 min) con reloj visible que corre hacia abajo.
 * Independiente del horario de acceso: el horario solo se revisa al INICIAR sesión;
 * este reloj solo cuenta inactividad. Si al cerrarse por inactividad el usuario ya está
 * fuera de su horario, el login no lo deja volver a entrar (regla acordada).
 */
@Injectable({ providedIn: 'root' })
export class InactividadService {
  private readonly sesion = inject(SesionService);
  private readonly router = inject(Router);
  private readonly http = inject(HttpClient);
  private readonly avisos = inject(MatSnackBar);
  private readonly zona = inject(NgZone);

  private readonly restantes = signal(MINUTOS_INACTIVIDAD * 60);
  readonly segundos = this.restantes.asReadonly();
  readonly reloj = computed(() => formatoReloj(this.restantes()));
  /** Últimos 5 minutos: el reloj se pone en ámbar; último minuto: en rojo. */
  readonly nivel = computed(() => (this.restantes() <= 60 ? 'critico' : this.restantes() <= 300 ? 'aviso' : 'normal'));

  private temporizador?: ReturnType<typeof setInterval>;
  private ultimoGuardado = 0;
  private ultimoPing = 0;
  private cerrando = false;
  private readonly alActividad = () => this.registrarActividad();

  /** Arranca el reloj en 30:00 (al entrar a la app). */
  iniciar(destruir: DestroyRef): void {
    this.detener();
    this.cerrando = false;
    const ahora = Date.now();
    this.ultimoPing = ahora;
    this.guardarActividad(ahora); // nunca hereda la hora de una sesión anterior
    this.restantes.set(segundosRestantes(ahora, ahora));

    this.zona.runOutsideAngular(() => {
      for (const evento of EVENTOS) {
        document.addEventListener(evento, this.alActividad, { capture: true, passive: true });
      }
      this.temporizador = setInterval(() => this.zona.run(() => this.tic()), 1000);
    });
    destruir.onDestroy(() => this.detener());
  }

  detener(): void {
    if (this.temporizador) clearInterval(this.temporizador);
    this.temporizador = undefined;
    for (const evento of EVENTOS) {
      document.removeEventListener(evento, this.alActividad, { capture: true });
    }
  }

  private registrarActividad(): void {
    const ahora = Date.now();
    if (ahora - this.ultimoGuardado < 1000) return; // como mucho una escritura por segundo
    this.guardarActividad(ahora);

    // Mantener viva la cookie del servidor mientras el usuario trabaja sin hacer peticiones.
    if (ahora - this.ultimoPing >= MANTENER_VIVA_MS) {
      this.ultimoPing = ahora;
      void firstValueFrom(this.http.get('/api/sesion')).catch(() => undefined);
    }
  }

  private guardarActividad(ahora: number): void {
    this.ultimoGuardado = ahora;
    try {
      localStorage.setItem(CLAVE_ULTIMA_ACTIVIDAD, String(ahora));
    } catch {
      /* almacenamiento no disponible: se usa solo el valor en memoria */
    }
  }

  private ultimaActividad(): number {
    try {
      const valor = Number(localStorage.getItem(CLAVE_ULTIMA_ACTIVIDAD));
      return Number.isFinite(valor) && valor > 0 ? Math.max(valor, this.ultimoGuardado) : this.ultimoGuardado;
    } catch {
      return this.ultimoGuardado;
    }
  }

  private tic(): void {
    const restan = segundosRestantes(Date.now(), this.ultimaActividad());
    this.restantes.set(restan);
    if (restan === 0) void this.cerrarPorInactividad();
  }

  private async cerrarPorInactividad(): Promise<void> {
    if (this.cerrando) return;
    this.cerrando = true;
    this.detener();
    await this.sesion.cerrarSesion(); // aunque el servidor ya la haya vencido, limpia la sesión local
    await this.router.navigateByUrl('/acceso');
    this.avisos.open(
      `Tu sesión se cerró por ${MINUTOS_INACTIVIDAD} minutos sin actividad. Vuelve a iniciar sesión.`,
      'Cerrar',
      { duration: 10000 },
    );
  }
}
