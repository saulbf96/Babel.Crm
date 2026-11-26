import { DatePipe, DecimalPipe } from '@angular/common';
import { HttpErrorResponse } from '@angular/common/http';
import { Component, DestroyRef, TemplateRef, computed, inject, signal, viewChild } from '@angular/core';
import { MatDialog, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatPaginatorModule } from '@angular/material/paginator';
import { PAGINADOR_EN_ESPANOL, Paginacion, TAMANOS_PAGINA } from '../../shared/paginacion/paginacion';
import { exportarExcel, fechaExcel, marcaArchivo } from '../../shared/exportar/excel';
import { MatTooltipModule } from '@angular/material/tooltip';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatButtonToggleModule } from '@angular/material/button-toggle';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { MatSelectModule } from '@angular/material/select';
import { MatSnackBar } from '@angular/material/snack-bar';
import { MatTableModule } from '@angular/material/table';
import { BajasService, CausaBaja, EmpleadoBaja, EstatusBaja } from '../../core/bajas/bajas.service';
import { SesionService } from '../../core/sesion/sesion.service';

/** Minúsculas y sin acentos, para buscar sin importar cómo se escriba. */
function normalizar(texto: string): string {
  return (texto ?? '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim();
}

const cacheBuscable = new WeakMap<EmpleadoBaja, string>();
function textoBuscable(e: EmpleadoBaja): string {
  let t = cacheBuscable.get(e);
  if (t === undefined) {
    t = normalizar([e.nombreCompleto, e.usuario, e.puesto, e.causaBaja, e.comentarioBaja].filter(Boolean).join(' '));
    cacheBuscable.set(e, t);
  }
  return t;
}

const COMENTARIO_MIN = 10;
const COMENTARIO_MAX = 500;

/** Fecha de hoy en formato yyyy-MM-dd (hora local). */
function hoy(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/**
 * Bajas de personal (reemplaza FRM_BAJAPERSONAL, que en BABEL estaba roto).
 * Baja lógica: el empleado, sus asignaciones y su usuario quedan inactivos; se puede reactivar.
 */
@Component({
  selector: 'app-bajas',
  imports: [
    DatePipe,
    DecimalPipe,
    ReactiveFormsModule,
    MatButtonModule,
    MatButtonToggleModule,
    MatDialogModule,
    MatTooltipModule,
    MatPaginatorModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    MatProgressBarModule,
    MatSelectModule,
    MatTableModule,
  ],
  providers: [PAGINADOR_EN_ESPANOL],
  templateUrl: './bajas.html',
  styleUrl: './bajas.css',
})
export class Bajas {
  private readonly servicio = inject(BajasService);
  private readonly sesion = inject(SesionService);
  private readonly avisos = inject(MatSnackBar);
  private readonly fb = inject(NonNullableFormBuilder);

  protected readonly cartera = this.sesion.cartera;
  protected readonly cargando = signal(false);
  protected readonly guardando = signal(false);
  protected readonly empleados = signal<EmpleadoBaja[]>([]);
  protected readonly causas = signal<CausaBaja[]>([]);
  protected readonly estatus = signal<EstatusBaja>('Activos');
  /** Búsqueda en tiempo real: nombre, usuario, puesto, causa o comentario de la baja. */
  protected readonly buscar = signal('');
  protected readonly columnas = ['num', 'empleado', 'puesto', 'ingreso', 'cuentas', 'estatus', 'acciones'];

  /** Se cargan TODOS una vez; estatus y búsqueda se filtran en el navegador (instantáneo). */
  protected readonly filtrados = computed(() => {
    const palabras = normalizar(this.buscar()).split(/\s+/).filter(Boolean);
    const estatus = this.estatus();
    return this.empleados().filter(
      (e) =>
        (estatus === 'Todos' || (estatus === 'Activos' ? e.activo : !e.activo)) &&
        palabras.every((p) => textoBuscable(e).includes(p)),
    );
  });

  protected readonly pag = new Paginacion(this.filtrados);
  protected readonly tamanos = TAMANOS_PAGINA;

  private readonly dialogo = inject(MatDialog);
  private readonly plantilla = viewChild.required<TemplateRef<unknown>>('dlgBaja');
  private readonly plantillaDetalle = viewChild.required<TemplateRef<unknown>>('dlgDetalle');

  /** Baja cuyo detalle (comentario completo) se está viendo. */
  protected readonly detalle = signal<EmpleadoBaja | null>(null);

  protected verDetalle(e: EmpleadoBaja): void {
    this.detalle.set(e);
    this.dialogo
      .open(this.plantillaDetalle(), { width: '560px', maxWidth: '95vw', maxHeight: '90vh', autoFocus: false })
      .afterClosed()
      .subscribe(() => this.detalle.set(null));
  }
  private ventana?: MatDialogRef<unknown>;

  /** Empleado seleccionado y qué se va a hacer con él. */
  protected readonly seleccionado = signal<EmpleadoBaja | null>(null);
  protected readonly modo = signal<'baja' | 'reactivar'>('baja');
  protected readonly error = signal<string | null>(null);

  protected readonly hoy = hoy();
  protected readonly comentarioMax = COMENTARIO_MAX;
  protected readonly comentarioMin = COMENTARIO_MIN;

  protected readonly formulario = this.fb.group({
    idCausaBaja: [0, [Validators.min(1)]],
    comentario: ['', [Validators.required, Validators.minLength(COMENTARIO_MIN), Validators.maxLength(COMENTARIO_MAX)]],
  });

  constructor() {
    this.servicio.causas().then((c) => this.causas.set(c)).catch(() => this.aviso('No se pudieron cargar las causas de baja.'));
    this.cargar();
    // Al regresar a la pestaña se recarga en segundo plano (cambios hechos en otra pantalla).
    const alVolver = () => {
      if (document.visibilityState === 'visible' && !this.cargando() && !this.seleccionado()) void this.cargar(true);
    };
    document.addEventListener('visibilitychange', alVolver);
    inject(DestroyRef).onDestroy(() => document.removeEventListener('visibilitychange', alVolver));
  }

  /** @param silencioso true = sin barra de progreso y sin regresar a la página 1. */
  protected async cargar(silencioso = false): Promise<void> {
    if (!silencioso) this.cargando.set(true);
    const pagina = this.pag.indice();
    try {
      this.empleados.set(await this.servicio.consultar('', 'Todos'));
      if (silencioso) this.pag.indice.set(pagina);
    } catch {
      this.aviso('No se pudieron cargar los empleados.');
    } finally {
      this.cargando.set(false);
    }
  }

  protected filtrar(valor: string): void {
    this.buscar.set(valor ?? '');
    this.pag.reiniciar();
  }

  /** Cambiar Activos / Dados de baja / Todos es instantáneo: no va al servidor. */
  protected cambiarEstatus(valor: EstatusBaja): void {
    this.estatus.set(valor);
    this.pag.reiniciar();
  }

  protected abrir(e: EmpleadoBaja, modo: 'baja' | 'reactivar'): void {
    this.seleccionado.set(e);
    this.modo.set(modo);
    this.error.set(null);
    this.formulario.reset({ idCausaBaja: 0, comentario: '' });
    // En reactivación no se pide causa. La fecha de baja es siempre hoy (no se captura).
    const causa = this.formulario.controls.idCausaBaja;
    if (modo === 'reactivar') {
      causa.disable();
    } else {
      causa.enable();
    }
    // Ventana al centro de la pantalla: no importa en qué renglón esté.
    this.ventana = this.dialogo.open(this.plantilla(), {
      width: '720px',
      maxWidth: '95vw',
      maxHeight: '90vh',
      disableClose: true,
      autoFocus: 'first-tabbable',
    });
    this.ventana.afterClosed().subscribe(() => {
      this.seleccionado.set(null);
      this.error.set(null);
    });
  }

  protected cerrar(): void {
    if (this.ventana) {
      this.ventana.close();
    } else {
      this.seleccionado.set(null);
      this.error.set(null);
    }
  }

  protected async confirmar(): Promise<void> {
    const e = this.seleccionado();
    if (!e || this.guardando()) return;
    if (this.formulario.invalid) {
      this.formulario.markAllAsTouched();
      return;
    }

    this.guardando.set(true);
    this.error.set(null);
    const { idCausaBaja, comentario } = this.formulario.getRawValue();
    try {
      if (this.modo() === 'baja') {
        const r = await this.servicio.darDeBaja(e.idEmpleado, { idCausaBaja, fechaBaja: this.hoy, comentario: comentario.trim() });
        const cuentas = r.cuentasAsignadas > 0
          ? ` Tenía ${r.cuentasAsignadas.toLocaleString('es-MX')} cuentas asignadas: reasígnalas en "Asignar personal".`
          : '';
        this.aviso(`${e.nombreCompleto} quedó dado de baja y su usuario desactivado.${cuentas}`, 8000);
      } else {
        await this.servicio.reactivar(e.idEmpleado, comentario.trim());
        this.aviso(`${e.nombreCompleto} reactivado. Deberá cambiar su contraseña al entrar.`, 5000);
      }
      this.cerrar();
      // Refresca sin regresar a la página 1.
      const pagina = this.pag.indice();
      await this.cargar(true);
      this.pag.indice.set(pagina);
    } catch (err) {
      this.error.set(
        err instanceof HttpErrorResponse && err.status === 400 && err.error?.title
          ? err.error.title
          : 'No se pudo completar la operación. Intenta de nuevo.',
      );
    } finally {
      this.guardando.set(false);
    }
  }

  // ---------- Exportar a Excel (exactamente lo que se ve: filtro + búsqueda) ----------
  protected readonly exportando = signal(false);

  protected async exportar(): Promise<void> {
    if (this.exportando()) return;
    this.exportando.set(true);
    try {
      const etiquetas: Record<EstatusBaja, string> = { Activos: 'Activos', Bajas: 'Dados de baja', Todos: 'Todos' };
      const estatus = etiquetas[this.estatus()];
      const busqueda = this.buscar().trim();
      const ahora = new Date();
      await exportarExcel({
        archivo: `bajas_${this.estatus().toLowerCase()}_${marcaArchivo(ahora)}`,
        hoja: 'Bajas',
        titulo: `Bajas de personal · ${this.cartera()} · ${estatus}`,
        detalle:
          `Filtro: ${estatus}` +
          (busqueda ? ` · Búsqueda: "${busqueda}"` : '') +
          ` · ${this.filtrados().length} empleado(s) · Generado por ${this.sesion.usuario()} el ` +
          ahora.toLocaleString('es-MX', { dateStyle: 'short', timeStyle: 'short' }),
        filas: this.filtrados(),
        columnas: [
          { titulo: 'Empleado', valor: (e) => e.nombreCompleto, ancho: 36 },
          { titulo: 'Usuario', valor: (e) => e.usuario ?? '', ancho: 14 },
          { titulo: 'Puesto', valor: (e) => e.puesto, ancho: 26 },
          { titulo: 'Ingreso', valor: (e) => fechaExcel(e.fechaIngreso), ancho: 12, formato: 'dd/mm/yyyy' },
          { titulo: 'Cuentas', valor: (e) => e.cuentasAsignadas, ancho: 10 },
          { titulo: 'Estatus', valor: (e) => (e.activo ? 'Activo' : 'Baja'), ancho: 10 },
          {
            titulo: 'Fecha de baja',
            valor: (e) => (e.activo ? null : e.fechaRegistroBaja ? new Date(e.fechaRegistroBaja) : fechaExcel(e.fechaBaja)),
            ancho: 18,
            formato: 'dd/mm/yyyy hh:mm',
          },
          { titulo: 'Causa', valor: (e) => (e.activo ? '' : e.causaBaja ?? ''), ancho: 22 },
          { titulo: 'Registró la baja', valor: (e) => (e.activo ? '' : e.usuarioBaja ?? ''), ancho: 16 },
          { titulo: 'Comentario', valor: (e) => (e.activo ? '' : e.comentarioBaja ?? ''), ancho: 60, ajustar: true },
        ],
      });
    } catch {
      this.aviso('No se pudo generar el archivo de Excel.');
    } finally {
      this.exportando.set(false);
    }
  }

  private aviso(mensaje: string, duracion = 4000): void {
    this.avisos.open(mensaje, 'Cerrar', { duration: duracion });
  }
}
