import { BreakpointObserver, Breakpoints } from '@angular/cdk/layout';
import { Component, DestroyRef, inject } from '@angular/core';
import { MatTooltipModule } from '@angular/material/tooltip';
import { InactividadService, MINUTOS_INACTIVIDAD } from '../core/sesion/inactividad';
import { toSignal } from '@angular/core/rxjs-interop';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatListModule } from '@angular/material/list';
import { MatSidenavModule } from '@angular/material/sidenav';
import { MatToolbarModule } from '@angular/material/toolbar';
import { Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { map } from 'rxjs';
import { SesionService } from '../core/sesion/sesion.service';

/** Estructura principal: barra superior y menú lateral según los perfiles del usuario. */
@Component({
  selector: 'app-shell',
  imports: [
    MatButtonModule,
    MatIconModule,
    MatListModule,
    MatSidenavModule,
    MatToolbarModule,
    MatTooltipModule,
    RouterLink,
    RouterLinkActive,
    RouterOutlet,
  ],
  templateUrl: './shell.html',
  styleUrl: './shell.css',
})
export class Shell {
  protected readonly sesion = inject(SesionService);
  private readonly router = inject(Router);

  /** Reloj de inactividad: corre de 30:00 hacia abajo y se reinicia con cualquier actividad. */
  protected readonly inactividad = inject(InactividadService);
  protected readonly minutosInactividad = MINUTOS_INACTIVIDAD;

  constructor() {
    this.inactividad.iniciar(inject(DestroyRef));
  }

  protected readonly esMovil = toSignal(
    inject(BreakpointObserver).observe(Breakpoints.Handset).pipe(map((r) => r.matches)),
    { initialValue: false },
  );

  protected async salir(): Promise<void> {
    this.inactividad.detener();
    await this.sesion.cerrarSesion();
    await this.router.navigateByUrl('/acceso');
  }
}
