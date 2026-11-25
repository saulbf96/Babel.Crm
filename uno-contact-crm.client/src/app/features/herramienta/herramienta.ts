import { HttpErrorResponse } from '@angular/common/http';
import { Component, computed, inject, input, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { MatSelectModule } from '@angular/material/select';
import { MatSnackBar } from '@angular/material/snack-bar';
import { Router } from '@angular/router';
import { GestionService } from '../../core/gestion/gestion.service';
import {
  CuentaDetalle,
  CuentaResumen,
  DemograficoResumen,
  GestionResumen,
  PromesaResumen,
  SolicitudGestion,
  TelefonoResumen,
} from '../../core/gestion/gestion.models';
import { HerramientasService } from '../../core/herramientas/herramientas.service';
import {
  AgendaResumen,
  NegociacionResumen,
  NotaResumen,
  RecesoActivo,
  RecesoResumen,
  SolicitudActualizaDemografico,
  SolicitudAgenda,
  SolicitudNegociacion,
  SolicitudNota,
} from '../../core/herramientas/herramientas.models';

const TITULOS: Record<string, string> = {
  buscar: 'Buscar',
  notas: 'Notas',
  'bloc-notas': 'Bloc de Notas',
  calculadora: 'Calculadora / Negociaciones',
  'actualiza-informacion': 'Actualiza Información',
  expedientes: 'Expedientes',
  softphone: 'Softphone',
  bloquear: 'Bloquear (receso)',
  cancelar: 'Cancelar gestión',
  'agendar-llamada': 'Agendar Llamada',
};

/**
 * Pantallas funcionales de los submenús del MenuStrip de FRM_GESTION_CARTERA.
 * El modo llega desde `data.modo` de la ruta. Todas las consultas usan la
 * cartera de la sesión y los datos migrados de BABEL_UNIFICADA.
 */
@Component({
  selector: 'app-herramienta',
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
  templateUrl: './herramienta.html',
  styleUrl: './herramienta.css',
})
export class Herramienta {
  private readonly gestion = inject(GestionService);
  private readonly herramientas = inject(HerramientasService);
  private readonly avisos = inject(MatSnackBar);
  private readonly router = inject(Router);

  readonly modo = input('');

  protected readonly titulo = computed(() => TITULOS[this.modo()] ?? 'Herramienta');
  protected readonly usaCuenta = computed(() =>
    !['bloquear', 'bloc-notas'].includes(this.modo()));

  protected filtro = '';
  protected tipoSReceso = 'Receso';
  protected softphoneNumero = '';
  protected enLlamada = false;

  protected readonly cuentas = signal<CuentaResumen[]>([]);
  protected readonly idCuenta = signal<number | null>(null);
  protected readonly cuenta = signal<CuentaDetalle | null>(null);
  protected readonly telefonos = signal<TelefonoResumen[]>([]);
  protected readonly gestiones = signal<GestionResumen[]>([]);
  protected readonly promesas = signal<PromesaResumen[]>([]);
  protected readonly demograficos = signal<DemograficoResumen[]>([]);
  protected readonly notas = signal<NotaResumen[]>([]);
  protected readonly negociaciones = signal<NegociacionResumen[]>([]);
  protected readonly agenda = signal<AgendaResumen[]>([]);
  protected readonly recesos = signal<RecesoResumen[]>([]);
  protected readonly bloc = signal('');
  protected readonly recesoActivo = signal<RecesoActivo | null>(null);
  protected readonly minutosReceso = signal(0);
  protected readonly calculo = signal<{ montoFinal: number; abono: number; total: number } | null>(null);
  protected readonly ultimoNumero = signal('');
  protected readonly cargando = signal(true);
  protected readonly guardando = signal(false);

  protected nota: SolicitudNota = this.nuevaNota();
  protected agendaForm: SolicitudAgenda = this.nuevaAgenda();
  protected negociacion: SolicitudNegociacion = this.nuevaNegociacion();
  protected demografico: SolicitudActualizaDemografico = this.nuevoDemografico();
  protected nuevoTelefono = { numero: '', tipo: 'CELULAR', origen: 'Actualiza Información' };

  constructor() {
    void this.inicializar();
  }

  private async inicializar(): Promise<void> {
    this.cargando.set(true);
    try {
      await this.buscar();
      if (this.modo() === 'bloc-notas') {
        this.bloc.set((await this.herramientas.blocNota()).texto ?? '');
      }
      if (this.modo() === 'bloquear') await this.cargarRecesos();
      if (this.modo() === 'agendar-llamada') await this.cargarAgenda();
    } catch (e) {
      this.avisos.open(this.mensaje(e, 'No se pudo cargar la herramienta.'), 'Cerrar', { duration: 6000 });
    } finally {
      this.cargando.set(false);
    }
  }

  protected async buscar(): Promise<void> {
    try {
      this.cuentas.set(await this.gestion.consultarCuentas(this.filtro.trim() || undefined));
    } catch (e) {
      this.avisos.open(this.mensaje(e, 'No se pudieron consultar las cuentas.'), 'Cerrar');
    }
  }

  protected async seleccionar(fila: CuentaResumen): Promise<void> {
    this.idCuenta.set(fila.idCuenta);
    await this.cargarDetalle();
  }

  private async cargarDetalle(): Promise<void> {
    const id = this.idCuenta();
    if (!id) return;
    try {
      const promesasBase: Promise<unknown>[] = [
        this.gestion.cuenta(id),
        this.gestion.telefonos(id),
        this.gestion.gestiones(id),
        this.gestion.promesas(id),
        this.gestion.demograficos(id),
      ];
      if (this.modo() === 'notas') promesasBase.push(this.herramientas.notas(id));
      if (this.modo() === 'calculadora') promesasBase.push(this.herramientas.negociaciones(id));
      if (this.modo() === 'agendar-llamada') promesasBase.push(this.herramientas.agenda(id));

      const resultados = await Promise.all(promesasBase);
      this.cuenta.set(resultados[0] as CuentaDetalle);
      this.telefonos.set(resultados[1] as TelefonoResumen[]);
      this.gestiones.set(resultados[2] as GestionResumen[]);
      this.promesas.set(resultados[3] as PromesaResumen[]);
      const demograficos = resultados[4] as DemograficoResumen[];
      this.demograficos.set(demograficos);

      let desplazamiento = 5;
      if (this.modo() === 'notas') this.notas.set(resultados[desplazamiento++] as NotaResumen[]);
      if (this.modo() === 'calculadora') {
        this.negociaciones.set(resultados[desplazamiento++] as NegociacionResumen[]);
      }
      if (this.modo() === 'agendar-llamada') {
        this.agenda.set(resultados[desplazamiento++] as AgendaResumen[]);
      }

      const d = demograficos[0];
      this.demografico = {
        idCuenta: id,
        calle: d?.calle ?? '',
        colonia: d?.colonia ?? '',
        codigoPostal: d?.codigoPostal ?? '',
        delegacion: d?.delegacion ?? '',
        estado: d?.estado ?? '',
        telefono: d?.telefono ?? this.telefonos()[0]?.numero ?? '',
        email: d?.email ?? '',
      };
      this.nota = this.nuevaNota(id);
      this.agendaForm = this.nuevaAgenda(id, this.telefonos()[0]?.numero ?? '');
      this.negociacion = this.nuevaNegociacion(id, this.cuenta()?.saldo ?? 0);
      this.calculo.set(null);
    } catch (e) {
      this.avisos.open(this.mensaje(e, 'No se pudo cargar el detalle de la cuenta.'), 'Cerrar');
    }
  }

  protected abrirEnGestion(fila: CuentaResumen): void {
    void this.router.navigate(['/asesor'], { queryParams: { id: fila.idCuenta } });
  }

  protected abrirSeleccionado(): void {
    const id = this.idCuenta();
    if (id) void this.router.navigate(['/asesor'], { queryParams: { id } });
  }

  // ------------------------------ Notas ------------------------------------
  protected async guardarNota(): Promise<void> {
    const id = this.idCuenta();
    if (!id || !this.nota.texto?.trim()) {
      this.avisos.open('Selecciona una cuenta y captura la nota.', 'Cerrar');
      return;
    }
    await this.ejecutar(
      () => this.herramientas.registrarNota({ ...this.nota, idCuenta: id }),
      'Nota capturada.',
      async () => {
        this.nota = this.nuevaNota(id);
        this.notas.set(await this.herramientas.notas(id));
      },
    );
  }

  // -------------------------- Bloc de notas --------------------------------
  protected async guardarBloc(): Promise<void> {
    await this.ejecutar(
      () => this.herramientas.guardarBlocNota(this.bloc()),
      'Bloc de notas guardado.',
      async () => {
        this.bloc.set((await this.herramientas.blocNota()).texto ?? '');
      },
    );
  }

  // ---------------------------- Recesos ------------------------------------
  private async cargarRecesos(): Promise<void> {
    this.recesos.set(await this.herramientas.recesos());
  }

  protected async iniciarReceso(): Promise<void> {
    if (this.guardando()) return;
    this.guardando.set(true);
    try {
      const activo = await this.herramientas.iniciarReceso(this.tipoSReceso);
      this.recesoActivo.set(activo);
      this.minutosReceso.set(0);
      this.avisos.open(activo.mensaje || 'Receso iniciado.', 'Cerrar', { duration: 4000 });
      await this.cargarRecesos();
    } catch (e) {
      this.avisos.open(this.mensaje(e, 'No se pudo iniciar el receso.'), 'Cerrar', { duration: 6000 });
    } finally {
      this.guardando.set(false);
    }
  }

  protected async finalizarReceso(): Promise<void> {
    const activo = this.recesoActivo();
    if (!activo) return;
    await this.ejecutar(
      () => this.herramientas.finalizarReceso(activo.idReceso),
      'Receso finalizado.',
      async () => {
        this.recesoActivo.set(null);
        this.minutosReceso.set(0);
        await this.cargarRecesos();
      },
    );
  }

  protected actualizarMinutos(): void {
    const activo = this.recesoActivo();
    if (activo) {
      this.minutosReceso.set(Math.max(0, Math.floor((Date.now() - new Date(activo.inicio).getTime()) / 60000)));
    }
  }

  // -------------------------- Agendar llamada ------------------------------
  private async cargarAgenda(): Promise<void> {
    this.agenda.set(await this.herramientas.agenda());
  }

  protected async guardarAgenda(): Promise<void> {
    const id = this.idCuenta();
    if (!id || !this.agendaForm.fechaHora) {
      this.avisos.open('Selecciona una cuenta y captura la fecha.', 'Cerrar');
      return;
    }
    const solicitud: SolicitudAgenda = {
      ...this.agendaForm,
      idCuenta: id,
      fechaHora: new Date(this.agendaForm.fechaHora).toISOString(),
    };
    await this.ejecutar(
      () => this.herramientas.registrarAgenda(solicitud),
      'Llamada agendada.',
      async () => {
        this.agendaForm = this.nuevaAgenda(id, this.telefonos()[0]?.numero ?? '');
        this.agenda.set(await this.herramientas.agenda());
      },
    );
  }

  protected async cambiarEstatus(row: AgendaResumen, estatus: string): Promise<void> {
    await this.ejecutar(
      () => this.herramientas.cambiarEstatusAgenda(row.idAgenda, estatus),
      `Llamada ${estatus.toLowerCase()}.`,
      async () => {
        this.agenda.set(await this.herramientas.agenda());
      },
    );
  }

  // -------------------------- Calculadora ----------------------------------
  protected calcular(): void {
    const original = Number(this.negociacion.montoOriginal) || this.cuenta()?.saldo || 0;
    const descuento = Number(this.negociacion.porcentajeDescuento) || 0;
    const pagos = Math.max(1, Number(this.negociacion.numeroPagos) || 1);
    const montoFinal = Math.round((original * (1 - descuento / 100)) * 100) / 100;
    const abono = Math.round((montoFinal / pagos) * 100) / 100;
    this.negociacion.montoOriginal = original;
    this.negociacion.montoFinal = montoFinal;
    this.calculo.set({ montoFinal, abono, total: Math.round(abono * pagos * 100) / 100 });
  }

  protected async guardarNegociacion(): Promise<void> {
    const simulacion = this.calculo();
    const id = this.idCuenta();
    if (!id || !simulacion) {
      this.avisos.open('Simula primero la negociación.', 'Cerrar');
      return;
    }
    const solicitud: SolicitudNegociacion = {
      ...this.negociacion,
      idCuenta: id,
      montoFinal: simulacion.montoFinal,
      fechaPrimerPago: this.negociacion.fechaPrimerPago || null,
    };
    await this.ejecutar(
      () => this.herramientas.registrarNegociacion(solicitud),
      'Negociación guardada.',
      async () => {
        this.negociaciones.set(await this.herramientas.negociaciones(id));
      },
    );
  }

  // ----------------------- Actualiza información ---------------------------
  protected async guardarDemografico(): Promise<void> {
    const id = this.idCuenta();
    if (!id) {
      this.avisos.open('Selecciona una cuenta.', 'Cerrar');
      return;
    }
    await this.ejecutar(
      () => this.herramientas.actualizarDemografico({ ...this.demografico, idCuenta: id }),
      'Información actualizada.',
      async () => {
        this.demograficos.set(await this.gestion.demograficos(id));
      },
    );
  }

  protected async registrarTelefono(): Promise<void> {
    const id = this.idCuenta();
    if (!id || !this.nuevoTelefono.numero.trim()) {
      this.avisos.open('Captura un teléfono de 10 dígitos.', 'Cerrar');
      return;
    }
    if (this.nuevoTelefono.numero.replace(/\D/g, '').length !== 10) {
      this.avisos.open('EL TELEFONO DEBE SER DE 10 DIGITOS', 'Cerrar');
      return;
    }
    await this.ejecutar(
      () => this.gestion.registrarTelefono(id, this.nuevoTelefono),
      'Teléfono agregado.',
      async () => {
        this.nuevoTelefono = { numero: '', tipo: 'CELULAR', origen: 'Actualiza Información' };
        this.telefonos.set(await this.gestion.telefonos(id));
      },
    );
  }

  // ----------------------------- Softphone ---------------------------------
  protected async marcar(): Promise<void> {
    const id = this.idCuenta();
    const numero = this.softphoneNumero.trim();
    if (!id || !numero) {
      this.avisos.open('Selecciona una cuenta y un teléfono.', 'Cerrar');
      return;
    }
    const gestion: SolicitudGestion = {
      idCuenta: id,
      idTipoGestion: 1,
      comentario: 'Marcación desde softphone CRM',
      idTelefono: null,
      telefonoMarcado: numero,
      inbound: false,
      tiempoLlamadaSegundos: null,
      tiempoEscrituraSegundos: null,
    };
    await this.ejecutar(
      () => this.gestion.registrarGestion(gestion),
      `Marcando ${numero}.`,
      async () => {
        this.ultimoNumero.set(numero);
        this.enLlamada = true;
        this.gestiones.set(await this.gestion.gestiones(id));
      },
    );
  }

  protected colgar(): void {
    this.enLlamada = false;
    this.avisos.open('Llamada finalizada.', 'Cerrar', { duration: 3000 });
  }

  protected remarcar(): void {
    this.softphoneNumero = this.ultimoNumero();
    void this.marcar();
  }

  protected tecla(digito: string): void {
    this.softphoneNumero = (this.softphoneNumero + digito).slice(0, 15);
  }

  // ------------------------------ Cancelar ---------------------------------
  protected cancelarYSiguiente(): void {
    const lista = this.cuentas();
    const actual = lista.findIndex((c) => c.idCuenta === this.idCuenta());
    const siguiente = lista[(actual + 1) % Math.max(lista.length, 1)];
    this.idCuenta.set(null);
    this.cuenta.set(null);
    void this.router.navigate(
      ['/asesor'],
      { queryParams: siguiente ? { id: siguiente.idCuenta } : {} },
    );
  }

  private async ejecutar(
    accion: () => Promise<{ mensaje: string }>,
    mensaje: string,
    despues: () => Promise<void>,
    recalcularCuentas = true,
  ): Promise<void> {
    if (this.guardando()) return;
    this.guardando.set(true);
    try {
      const r = await accion();
      this.avisos.open(r.mensaje || mensaje, 'Cerrar', { duration: 4000 });
      await despues();
      if (recalcularCuentas) await this.buscar();
    } catch (e) {
      this.avisos.open(this.mensaje(e, 'No se pudo guardar.'), 'Cerrar', { duration: 6000 });
    } finally {
      this.guardando.set(false);
    }
  }

  private nuevaNota(idCuenta = 0): SolicitudNota {
    return {
      idCuenta,
      tipoSeguimiento: 'SEGUIMIENTO',
      fechaSeguimiento: this.localIso(new Date()),
      telefono: '',
      pagos: 0,
      importe: 0,
      texto: '',
    };
  }

  private nuevaAgenda(idCuenta = 0, telefono = ''): SolicitudAgenda {
    return {
      idCuenta,
      fechaHora: this.localIso(new Date(Date.now() + 3600000)),
      telefono,
      asunto: '',
    };
  }

  private nuevaNegociacion(idCuenta = 0, saldo = 0): SolicitudNegociacion {
    return {
      idCuenta,
      tipoNegociacion: 'DESCUENTO',
      tipoPago: 'PLAN DE PAGOS',
      montoOriginal: Math.round(saldo * 100) / 100,
      porcentajeDescuento: 0,
      montoFinal: Math.round(saldo * 100) / 100,
      numeroPagos: 1,
      fechaPrimerPago: new Date().toISOString().slice(0, 10),
      comentario: '',
    };
  }

  private nuevoDemografico(): SolicitudActualizaDemografico {
    return {
      idCuenta: 0,
      calle: '',
      colonia: '',
      codigoPostal: '',
      delegacion: '',
      estado: '',
      telefono: '',
      email: '',
    };
  }

  private localIso(fecha: Date): string {
    return new Date(fecha.getTime() - fecha.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
  }

  private mensaje(e: unknown, alterno: string): string {
    if (e instanceof HttpErrorResponse) return e.error?.title ?? e.error?.message ?? alterno;
    return alterno;
  }
}
