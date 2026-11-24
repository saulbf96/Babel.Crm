import { Component } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { RouterLink } from '@angular/router';

@Component({
  selector: 'app-acceso-denegado',
  imports: [MatButtonModule, RouterLink],
  template: `
    <h1>Acceso denegado</h1>
    <p>Tu perfil no tiene permiso para entrar a esta sección.</p>
    <a mat-stroked-button routerLink="/inicio">Ir al inicio</a>
  `,
})
export class AccesoDenegado {}
