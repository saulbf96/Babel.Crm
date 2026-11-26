import { HttpErrorResponse } from '@angular/common/http';
import { Component, computed, inject, signal } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatChipsModule } from '@angular/material/chips';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { MatSnackBar } from '@angular/material/snack-bar';
import { MatTableModule } from '@angular/material/table';
import { Cartera } from '../../core/catalogos/catalogos.models';
import { CarterasService } from '../../core/carteras/carteras.service';
import { SesionService } from '../../core/sesion/sesion.service';

/** Cambia cartera (equivale a FRM_CONSULTA_BASE de BABEL ADMINISTRATIVO). */
@Component({
  selector: 'app-cambiar-cartera',
  imports: [
    MatButtonModule,
    MatChipsModule,
    MatIconModule,
    MatProgressBarModule,
    MatTableModule,
  ],
  templateUrl: './cambiar-cartera.html',
  styleUrl: './cambiar-cartera.css',
})
export class CambiarCartera {
  private readonly carterasService = inject(CarterasService);
  private readonly avisos = inject(MatSnackBar);
  protected readonly sesion = inject(SesionService);

  protected readonly carteras = signal<Cartera[]>([]);
  protected readonly cargando = signal(true);
  protected readonly cambiando = signal<number | null>(null);
  protected readonly actual = computed(() => this.sesion.sesion()?.idCartera ?? 0);

  protected readonly columnas = ['num', 'cartera', 'cliente', 'departamento', 'accion'];

  constructor() {
    void this.cargar();
  }

  private async cargar(): Promise<void> {
    this.cargando.set(true);
    try {
      this.carteras.set(await this.carterasService.consultar());
    } catch {
      this.avisos.open('No se pudieron cargar las carteras.', 'Cerrar');
    } finally {
      this.cargando.set(false);
    }
  }

  protected async cambiar(cartera: Cartera): Promise<void> {
    if (cartera.idCartera === this.actual() || this.cambiando() !== null) return;

    this.cambiando.set(cartera.idCartera);
    try {
      await this.sesion.cambiarCartera(cartera.idCartera);
      this.avisos.open(`Ahora estás en la cartera ${cartera.nombre}.`, 'Cerrar', { duration: 4000 });
    } catch (e) {
      this.avisos.open(this.mensajeDeError(e), 'Cerrar', { duration: 6000 });
    } finally {
      this.cambiando.set(null);
    }
  }

  private mensajeDeError(e: unknown): string {
    if (e instanceof HttpErrorResponse) {
      return e.error?.title ?? 'No se pudo cambiar la cartera.';
    }
    return 'No hay comunicación con el servidor.';
  }
}
