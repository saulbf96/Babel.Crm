import { Component, inject } from '@angular/core';
import { MatCardModule } from '@angular/material/card';
import { SesionService } from '../../core/sesion/sesion.service';

@Component({
  selector: 'app-inicio',
  imports: [MatCardModule],
  template: `
    <h1>Bienvenido, {{ sesion.usuario() }}</h1>
    <mat-card appearance="outlined">
      <mat-card-content>
        <p>Perfiles: {{ sesion.sesion()?.perfiles?.join(', ') }}</p>
        <p>Elige un módulo en el menú de la izquierda.</p>
      </mat-card-content>
    </mat-card>
  `,
})
export class Inicio {
  protected readonly sesion = inject(SesionService);
}
