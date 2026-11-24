import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatCheckboxModule } from '@angular/material/checkbox';
import { MatChipsModule } from '@angular/material/chips';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { MatTableModule } from '@angular/material/table';
import { EmpleadosService } from '../../core/empleados/empleados.service';
import { EmpleadoResumen } from '../../core/empleados/empleados.models';

/** Pantalla "Consulta Empleados" (equivale a FRM_CONSULTAEMPLEADOS de BABEL ADMINISTRATIVO). */
@Component({
  selector: 'app-empleados',
  imports: [
    FormsModule,
    MatButtonModule,
    MatCheckboxModule,
    MatChipsModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    MatProgressBarModule,
    MatTableModule,
  ],
  templateUrl: './empleados.html',
  styleUrl: './empleados.css',
})
export class Empleados {
  private readonly servicio = inject(EmpleadosService);

  protected readonly nombre = signal('');
  protected readonly soloActivos = signal(true);
  protected readonly empleados = signal<EmpleadoResumen[]>([]);
  protected readonly cargando = signal(false);
  protected readonly busco = signal(false);

  protected readonly columnas = ['idEmpleado', 'nombreCompleto', 'puesto', 'departamento', 'cliente', 'rfc', 'email', 'fechaIngreso', 'activo'];

  constructor() {
    void this.buscar();
  }

  protected async buscar(): Promise<void> {
    this.cargando.set(true);
    try {
      const datos = await this.servicio.consultar({
        nombre: this.nombre().trim() || undefined,
        soloActivos: this.soloActivos(),
      });
      this.empleados.set(datos);
    } finally {
      this.cargando.set(false);
      this.busco.set(true);
    }
  }

  protected limpiar(): void {
    this.nombre.set('');
    this.soloActivos.set(true);
    void this.buscar();
  }
}
