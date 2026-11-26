import { Component, input } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatChipsModule } from '@angular/material/chips';
import { MatIconModule } from '@angular/material/icon';
import { RouterLink } from '@angular/router';

/**
 * Pantalla de un submenú migrado del FRM_GESTION_CARTERA legacy.
 * Los datos de cada pantalla vienen de `data` en la ruta (withComponentInputBinding).
 */
@Component({
  selector: 'app-legacy-modulo',
  imports: [MatButtonModule, MatCardModule, MatChipsModule, MatIconModule, RouterLink],
  templateUrl: './legacy-modulo.html',
  styleUrl: './legacy-modulo.css',
})
export class LegacyModulo {
  readonly titulo = input('');
  readonly descripcion = input('');
  readonly formulario = input('');
  readonly procedimientos = input<string[]>([]);
  readonly tablas = input<string[]>([]);
  readonly estado = input('Pendiente de migración de datos');
}
