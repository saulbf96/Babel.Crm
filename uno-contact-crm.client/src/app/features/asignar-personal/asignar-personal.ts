import { HttpErrorResponse } from '@angular/common/http';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatCheckboxModule } from '@angular/material/checkbox';
import { MatChipsModule } from '@angular/material/chips';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { MatSelectModule } from '@angular/material/select';
import { MatSnackBar } from '@angular/material/snack-bar';
import { MatTableModule } from '@angular/material/table';
import { Catalogos } from '../../core/catalogos/catalogos.models';
import { CatalogosService } from '../../core/catalogos/catalogos.service';
import { OperativoResumen, PersonalCartera } from '../../core/carteras/carteras.models';
import { CarterasService } from '../../core/carteras/carteras.service';
import { SesionService } from '../../core/sesion/sesion.service';

/** Asignar personal a cartera (equivale a FRM_ASIGNARPERSONAL de BABEL ADMINISTRATIVO). */
@Component({
  selector: 'app-asignar-personal',
  imports: [
    FormsModule,
    MatButtonModule,
    MatCheckboxModule,
    MatChipsModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    MatProgressBarModule,
    MatSelectModule,
    MatTableModule,
  ],
  templateUrl: './asignar-personal.html',
  styleUrl: './asignar-personal.css',
})
export class AsignarPersonal {
  private readonly catalogosService = inject(CatalogosService);
  private readonly carterasService = inject(CarterasService);
  private readonly sesion = inject(SesionService);
  private readonly avisos = inject(MatSnackBar);

  protected readonly catalogos = signal<Catalogos | null>(null);
  protected readonly carteraId = signal(0);
  protected readonly texto = signal('');
  protected readonly departamentoId = signal(0);
  protected readonly registrarOperativo = signal(false);
  protected readonly personal = signal<PersonalCartera[]>([]);
  protected readonly operativo = signal<OperativoResumen[]>([]);
  protected readonly seleccionados = signal<ReadonlySet<number>>(new Set());
  protected readonly cargando = signal(true);
  protected readonly guardando = signal(false);
  protected readonly restaurando = signal(false);
  protected readonly busco = signal(false);

  protected readonly columnas = ['seleccion', 'nombre', 'puesto', 'departamento', 'cartera', 'estado'];
  protected readonly seleccionadosCount = computed(() => this.seleccionados().size);
  protected readonly todosSeleccionados = computed(() => {
    const visibles = this.personal();
    return visibles.length > 0 && visibles.every((p) => this.seleccionados().has(p.idEmpleado));
  });

  constructor() {
    void this.inicializar();
  }

  private async inicializar(): Promise<void> {
    this.cargando.set(true);
    try {
      const catalogos = await this.catalogosService.consultar();
      this.catalogos.set(catalogos);

      const actual = this.sesion.sesion()?.idCartera ?? catalogos.carteras[0]?.idCartera ?? 0;
      this.carteraId.set(actual);
      this.departamentoId.set(
        catalogos.carteras.find((c) => c.idCartera === actual)?.idDepartamento ?? 0,
      );
      await this.buscar();
    } catch {
      this.avisos.open('No se pudieron cargar las carteras.', 'Cerrar');
    } finally {
      this.cargando.set(false);
    }
  }

  protected async cambiarCartera(idCartera: number): Promise<void> {
    this.carteraId.set(idCartera);
    this.seleccionados.set(new Set());
    this.departamentoId.set(
      this.catalogos()?.carteras.find((c) => c.idCartera === idCartera)?.idDepartamento ?? 0,
    );
    await this.buscar();
  }

  protected async buscar(): Promise<void> {
    const idCartera = this.carteraId();
    if (!idCartera) return;

    this.cargando.set(true);
    try {
      const [personal, operativo] = await Promise.all([
        this.carterasService.personal(idCartera, this.texto().trim() || undefined),
        this.carterasService.operativo(idCartera),
      ]);
      this.personal.set(personal);
      this.operativo.set(operativo);
      this.busco.set(true);
    } catch (e) {
      this.avisos.open(this.mensajeDeError(e), 'Cerrar', { duration: 6000 });
    } finally {
      this.cargando.set(false);
    }
  }

  protected estaSeleccionado(idEmpleado: number): boolean {
    return this.seleccionados().has(idEmpleado);
  }

  protected toggle(idEmpleado: number): void {
    const siguiente = new Set(this.seleccionados());
    if (siguiente.has(idEmpleado)) siguiente.delete(idEmpleado);
    else siguiente.add(idEmpleado);
    this.seleccionados.set(siguiente);
  }

  protected seleccionarTodos(): void {
    this.seleccionados.set(
      this.todosSeleccionados()
        ? new Set()
        : new Set(this.personal().map((p) => p.idEmpleado)),
    );
  }

  protected async asignar(): Promise<void> {
    const ids = [...this.seleccionados()];
    if (ids.length === 0) {
      this.avisos.open('Selecciona al menos un empleado.', 'Cerrar');
      return;
    }

    this.guardando.set(true);
    try {
      const resultado = await this.carterasService.asignar(
        this.carteraId(),
        ids,
        this.departamentoId() || null,
        this.registrarOperativo(),
      );
      this.avisos.open(
        `${resultado.mensaje} Asignados: ${resultado.asignados}. Omitidos: ${resultado.omitidos}.`,
        'Cerrar',
        { duration: 5000 },
      );
      this.seleccionados.set(new Set());
      await this.buscar();
    } catch (e) {
      this.avisos.open(this.mensajeDeError(e), 'Cerrar', { duration: 6000 });
    } finally {
      this.guardando.set(false);
    }
  }

  protected async restaurar(): Promise<void> {
    const ids = this.operativo().map((o) => o.idEmpleado);
    if (ids.length === 0) {
      this.avisos.open('No hay personal operativo que restaurar en esta cartera.', 'Cerrar');
      return;
    }

    this.restaurando.set(true);
    try {
      const resultado = await this.carterasService.restaurar(ids);
      this.avisos.open(resultado.mensaje, 'Cerrar', { duration: 5000 });
      await this.buscar();
    } catch (e) {
      this.avisos.open(this.mensajeDeError(e), 'Cerrar', { duration: 6000 });
    } finally {
      this.restaurando.set(false);
    }
  }

  private mensajeDeError(e: unknown): string {
    if (e instanceof HttpErrorResponse) {
      return e.error?.title ?? 'No se pudo completar la operación.';
    }
    return 'No hay comunicación con el servidor.';
  }
}
