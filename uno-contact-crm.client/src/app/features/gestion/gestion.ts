import { HttpErrorResponse } from '@angular/common/http';
import { Component, inject, signal } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { MatSelectModule } from '@angular/material/select';
import { MatSnackBar } from '@angular/material/snack-bar';
import { GestionService } from '../../core/gestion/gestion.service';
import {
  CuentaDetalle,
  CuentaResumen,
  DemograficoResumen,
  GestionResumen,
  PromesaResumen,
  SolicitudCuenta,
  SolicitudGestion,
  SolicitudPromesa,
  SolicitudTelefono,
  TelefonoResumen,
  TipoGestion,
} from '../../core/gestion/gestion.models';
import { SesionService } from '../../core/sesion/sesion.service';

/**
 * Gestión de cartera inicial (equivalente a FRM_GESTION_CARTERA).
 * Permite localizar/capturar cuenta, ver teléfonos, demográficos e historial,
 * y registrar gestión, teléfono o promesa. La cartera viene de la sesión.
 */
@Component({
  selector: 'app-gestion',
  imports: [
    FormsModule,
    MatButtonModule,
    MatCardModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    MatProgressBarModule,
    MatSelectModule,
  ],
  templateUrl: './gestion.html',
  styleUrl: './gestion.css',
})
export class Gestion {
  private readonly servicio = inject(GestionService);
  private readonly sesion = inject(SesionService);
  private readonly avisos = inject(MatSnackBar);
  private readonly ruta = inject(ActivatedRoute);

  protected readonly cuentas = signal<CuentaResumen[]>([]);
  protected readonly tipos = signal<TipoGestion[]>([]);
  protected readonly cuenta = signal<CuentaDetalle | null>(null);
  protected readonly telefonos = signal<TelefonoResumen[]>([]);
  protected readonly gestiones = signal<GestionResumen[]>([]);
  protected readonly promesas = signal<PromesaResumen[]>([]);
  protected readonly demograficos = signal<DemograficoResumen[]>([]);
  protected readonly cargando = signal(true);
  protected readonly guardando = signal(false);

  protected filtro = '';
  protected nuevaCuenta: SolicitudCuenta = this.crearSolicitudCuenta();
  protected nuevoTelefono: SolicitudTelefono = { numero: '', tipo: '', calificacion: null, origen: '' };
  protected nuevaGestion: SolicitudGestion = this.crearSolicitudGestion();
  protected nuevaPromesa: SolicitudPromesa = this.crearSolicitudPromesa();

  constructor() {
    void this.inicializar();
  }

  protected get carteraActiva(): string {
    return this.sesion.sesion()?.cartera ?? 'Cartera de la sesión';
  }

  private async inicializar(): Promise<void> {
    this.cargando.set(true);
    try {
      this.tipos.set(await this.servicio.tipos());
      await this.buscar();

      const id = Number(this.ruta.snapshot.queryParamMap.get('id'));
      if (id > 0) {
        const fila = this.cuentas().find((c) => c.idCuenta === id);
        if (fila) await this.seleccionar(fila);
        else await this.cargarDetalle(id);
      }
    } catch (e) {
      this.avisos.open(this.mensajeDeError(e, 'No se pudo cargar Gestión.'), 'Cerrar', { duration: 6000 });
    } finally {
      this.cargando.set(false);
    }
  }

  protected async buscar(): Promise<void> {
    try {
      this.cuentas.set(await this.servicio.consultarCuentas(this.filtro.trim() || undefined));
    } catch (e) {
      this.avisos.open(this.mensajeDeError(e, 'No se pudieron consultar las cuentas.'), 'Cerrar');
    }
  }

  protected async crearCuenta(): Promise<void> {
    if (this.guardando()) return;
    if (!this.nuevaCuenta.numeroCuenta?.trim() || !this.nuevaCuenta.idControlLegacy) {
      this.avisos.open('Captura el ID de control y el número de cuenta.', 'Cerrar');
      return;
    }

    this.guardando.set(true);
    try {
      const r = await this.servicio.crearCuenta(this.nuevaCuenta);
      this.avisos.open(`${r.mensaje} Cuenta #${r.id}.`, 'Cerrar', { duration: 5000 });
      this.nuevaCuenta = this.crearSolicitudCuenta();
      await this.buscar();
      await this.seleccionar({ idCuenta: r.id } as CuentaResumen);
    } catch (e) {
      this.avisos.open(this.mensajeDeError(e, 'No se pudo capturar la cuenta.'), 'Cerrar', { duration: 6000 });
    } finally {
      this.guardando.set(false);
    }
  }

  protected async seleccionar(fila: CuentaResumen): Promise<void> {
    await this.cargarDetalle(fila.idCuenta);
  }

  private async cargarDetalle(idCuenta: number): Promise<void> {
    try {
      const [cuenta, telefonos, gestiones, promesas, demograficos] = await Promise.all([
        this.servicio.cuenta(idCuenta),
        this.servicio.telefonos(idCuenta),
        this.servicio.gestiones(idCuenta),
        this.servicio.promesas(idCuenta),
        this.servicio.demograficos(idCuenta),
      ]);
      this.cuenta.set(cuenta);
      this.telefonos.set(telefonos);
      this.gestiones.set(gestiones);
      this.promesas.set(promesas);
      this.demograficos.set(demograficos);
      this.nuevoTelefono = { numero: '', tipo: '', calificacion: null, origen: '' };
      this.nuevaGestion = this.crearSolicitudGestion(idCuenta);
      this.nuevaPromesa = this.crearSolicitudPromesa(idCuenta);
    } catch (e) {
      this.avisos.open(this.mensajeDeError(e, 'No se pudo cargar el detalle de la cuenta.'), 'Cerrar');
    }
  }

  protected async registrarTelefono(): Promise<void> {
    const c = this.cuenta();
    if (!c || !this.nuevoTelefono.numero.trim()) {
      this.avisos.open('Captura un teléfono.', 'Cerrar');
      return;
    }
    await this.ejecutar(
      () => this.servicio.registrarTelefono(c.idCuenta, this.nuevoTelefono),
      'Teléfono capturado.',
      () => this.cargarDetalle(c.idCuenta),
    );
  }

  protected async registrarGestion(): Promise<void> {
    const c = this.cuenta();
    if (!c || !this.nuevaGestion.idTipoGestion) {
      this.avisos.open('Selecciona el tipo de gestión.', 'Cerrar');
      return;
    }
    await this.ejecutar(
      () => this.servicio.registrarGestion(this.nuevaGestion),
      'Gestión registrada.',
      () => this.cargarDetalle(c.idCuenta),
    );
  }

  protected async registrarPromesa(): Promise<void> {
    const c = this.cuenta();
    if (!c || !this.nuevaPromesa.monto || !this.nuevaPromesa.fechaPromesa) {
      this.avisos.open('Captura el monto y la fecha de promesa.', 'Cerrar');
      return;
    }
    await this.ejecutar(
      () => this.servicio.registrarPromesa(this.nuevaPromesa),
      'Promesa registrada.',
      () => this.cargarDetalle(c.idCuenta),
    );
  }

  private async ejecutar(
    accion: () => Promise<{ mensaje: string }>,
    mensaje: string,
    despues: () => Promise<void>,
  ): Promise<void> {
    if (this.guardando()) return;
    this.guardando.set(true);
    try {
      const r = await accion();
      this.avisos.open(r.mensaje || mensaje, 'Cerrar', { duration: 5000 });
      await despues();
      await this.buscar();
    } catch (e) {
      this.avisos.open(this.mensajeDeError(e, 'No se pudo guardar.'), 'Cerrar', { duration: 6000 });
    } finally {
      this.guardando.set(false);
    }
  }

  private crearSolicitudCuenta(): SolicitudCuenta {
    return {
      idControlLegacy: 0,
      numeroCuenta: '',
      nombreCliente: '',
      situacionCuenta: '',
      razonMora: '',
      saldo: null,
    };
  }

  private crearSolicitudGestion(idCuenta = 0): SolicitudGestion {
    return {
      idCuenta,
      idTipoGestion: 0,
      comentario: '',
      idTelefono: null,
      telefonoMarcado: '',
      inbound: false,
      tiempoLlamadaSegundos: null,
      tiempoEscrituraSegundos: null,
    };
  }

  private crearSolicitudPromesa(idCuenta = 0): SolicitudPromesa {
    return {
      idCuenta,
      idGestion: null,
      monto: 0,
      fechaPromesa: new Date().toISOString().slice(0, 10),
      lugarPago: '',
      fuenteIngreso: '',
      razonMora: '',
      notas: '',
    };
  }

  private mensajeDeError(e: unknown, alterno: string): string {
    if (e instanceof HttpErrorResponse) return e.error?.title ?? alterno;
    return alterno;
  }
}
