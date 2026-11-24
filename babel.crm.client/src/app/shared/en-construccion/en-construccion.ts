import { Component, input } from '@angular/core';
import { MatIconModule } from '@angular/material/icon';

/** Lugar reservado para un módulo que todavía no se migra. */
@Component({
  selector: 'app-en-construccion',
  imports: [MatIconModule],
  template: `
    <h1>{{ titulo() }}</h1>
    <p><mat-icon>construction</mat-icon> Módulo en construcción.</p>
  `,
})
export class EnConstruccion {
  /** Viene de data.titulo de la ruta (withComponentInputBinding). */
  readonly titulo = input('');
}
