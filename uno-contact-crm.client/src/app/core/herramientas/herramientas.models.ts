/** Modelos de las Herramientas del FRM_GESTION_CARTERA. */
export interface NotaResumen {
  idNota: number;
  tipoSeguimiento: string;
  fechaSeguimiento: string;
  telefono: string | null;
  pagos: number | null;
  importe: number | null;
  texto: string | null;
  fechaRegistro: string;
  empleado: string | null;
}

export interface BlocNota {
  texto: string;
  fechaRegistro: string | null;
}

export interface RecesoResumen {
  idReceso: number;
  tipoReceso: string | null;
  inicio: string;
  fin: string | null;
  minutos: number | null;
}

export interface RecesoActivo {
  idReceso: number;
  inicio: string;
  mensaje: string;
}

export interface AgendaResumen {
  idAgenda: number;
  idCuenta: number;
  numeroCuenta: string;
  nombreCliente: string | null;
  fechaHora: string;
  telefono: string | null;
  asunto: string | null;
  estatus: string;
  empleado: string | null;
}

export interface NegociacionResumen {
  idNegociacion: number;
  tipoNegociacion: string | null;
  tipoPago: string | null;
  montoOriginal: number;
  porcentajeDescuento: number;
  montoFinal: number;
  numeroPagos: number;
  fechaPrimerPago: string | null;
  comentario: string | null;
  fechaRegistro: string;
  empleado: string | null;
}

export interface SolicitudNota {
  idCuenta: number;
  tipoSeguimiento: string | null;
  fechaSeguimiento: string | null;
  telefono: string | null;
  pagos: number | null;
  importe: number | null;
  texto: string | null;
}

export interface SolicitudAgenda {
  idCuenta: number;
  fechaHora: string;
  telefono: string | null;
  asunto: string | null;
}

export interface SolicitudNegociacion {
  idCuenta: number;
  tipoNegociacion: string;
  tipoPago: string;
  montoOriginal: number;
  porcentajeDescuento: number;
  montoFinal: number;
  numeroPagos: number;
  fechaPrimerPago: string | null;
  comentario: string | null;
}

export interface SolicitudActualizaDemografico {
  idCuenta: number;
  calle: string | null;
  colonia: string | null;
  codigoPostal: string | null;
  delegacion: string | null;
  estado: string | null;
  telefono: string | null;
  email: string | null;
}

export interface ResultadoOperacion {
  id: number;
  mensaje: string;
}
