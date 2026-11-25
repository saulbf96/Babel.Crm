import { HttpErrorResponse } from '@angular/common/http';
import { Component, inject, signal } from '@angular/core';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { MatSelectModule } from '@angular/material/select';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Catalogos } from '../../core/catalogos/catalogos.models';
import { CatalogosService } from '../../core/catalogos/catalogos.service';
import { EmpleadosService } from '../../core/empleados/empleados.service';
import { SesionService } from '../../core/sesion/sesion.service';

/** Alta de empleados (equivale a FRM_ALTAEMPLEADOS de BABEL ADMINISTRATIVO). */
@Component({
  selector: 'app-alta-empleados',
  imports: [
    ReactiveFormsModule,
    MatButtonModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    MatProgressBarModule,
    MatSelectModule,
  ],
  templateUrl: './alta-empleados.html',
  styleUrl: './alta-empleados.css',
})
export class AltaEmpleados {
  private readonly catalogosService = inject(CatalogosService);
  private readonly empleadosService = inject(EmpleadosService);
  private readonly sesion = inject(SesionService);
  private readonly avisos = inject(MatSnackBar);

  protected readonly catalogos = signal<Catalogos | null>(null);
  protected readonly cargando = signal(true);
  protected readonly enviando = signal(false);

  /** Cartera activa de la sesión: el alta siempre se registra en ella, como el .exe. */
  protected readonly carteraActual = this.sesion.cartera;

  protected readonly formulario = inject(NonNullableFormBuilder).group({
    idPuesto: [0, [Validators.min(1)]],
    idSexo: [0, [Validators.min(1)]],
    idTurno: [0, [Validators.min(1)]],
    nombre: ['', [Validators.required, Validators.maxLength(100)]],
    paterno: ['', [Validators.required, Validators.maxLength(100)]],
    materno: ['', [Validators.required, Validators.maxLength(100)]],
  });

  constructor() {
    void this.cargar();
  }

  private async cargar(): Promise<void> {
    this.cargando.set(true);
    try {
      this.catalogos.set(await this.catalogosService.consultar());
    } catch {
      this.avisos.open('No se pudieron cargar los catálogos.', 'Cerrar');
    } finally {
      this.cargando.set(false);
    }
  }

  protected async guardar(): Promise<void> {
    if (this.formulario.invalid || this.enviando()) {
      this.formulario.markAllAsTouched();
      return;
    }

    this.enviando.set(true);
    try {
      const valores = this.formulario.getRawValue();
      const resultado = await this.empleadosService.alta({
        idPuesto: valores.idPuesto,
        idSexo: valores.idSexo,
        idTurno: valores.idTurno,
        nombre: valores.nombre.trim(),
        paterno: valores.paterno.trim(),
        materno: valores.materno.trim(),
      });
      this.avisos.open(
        `${resultado.mensaje} (ID ${resultado.idEmpleado})`,
        'Cerrar',
        { duration: 5000 },
      );
      this.limpiar();
    } catch (e) {
      this.avisos.open(this.mensajeDeError(e), 'Cerrar', { duration: 6000 });
    } finally {
      this.enviando.set(false);
    }
  }

  protected limpiar(): void {
    this.formulario.reset({
      idPuesto: 0,
      idSexo: 0,
      idTurno: 0,
      nombre: '',
      paterno: '',
      materno: '',
    });
  }

  private mensajeDeError(e: unknown): string {
    if (e instanceof HttpErrorResponse) {
      return e.error?.title ?? 'No se pudo dar de alta al empleado.';
    }
    return 'No hay comunicación con el servidor.';
  }
}
