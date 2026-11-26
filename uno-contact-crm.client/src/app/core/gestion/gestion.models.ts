/** Modelos del módulo de Gestión (equivalente a FRM_GESTION_CARTERA). */
export interface CuentaResumen {
  idCuenta: number;
  idCartera: number;
  cartera: string;
  idControlLegacy: number;
  numeroCuenta: string;
  nombreCliente: string | null;
  situacionCuenta: string | null;
  razonMora: string | null;
  saldo: number | null;
  empleado: string | null;
  activo: boolean;
  fechaRegistro: string;
}

export interface CuentaDetalle {
  idCuenta: number;
  idCartera: number;
  cartera: string;
  idControlLegacy: number;
  numeroCuenta: string;
  nombreCliente: string | null;
  situacionCuenta: string | null;
  razonMora: string | null;
  saldo: number | null;
  idSegmento: number;
  idProducto: number;
  idCampana: number;
  activo: boolean;
  fechaRegistro: string;
}

export interface TelefonoResumen {
  idTelefono: number;
  numero: string;
  tipo: string | null;
  calificacion: number | null;
  origen: string | null;
  activo: boolean;
  fechaRegistro: string;
}

export interface TipoGestion {
  idTipoGestion: number;
  nombre: string;
}

export interface GestionResumen {
  idGestion: number;
  idTipoGestion: number;
  tipoGestion: string;
  comentario: string | null;
  telefonoMarcado: string | null;
  inbound: boolean;
  fechaInicio: string;
  fechaFin: string | null;
  tiempoLlamadaSegundos: number | null;
  tiempoEscrituraSegundos: number | null;
  empleado: string | null;
}

export interface PromesaResumen {
  idPromesa: number;
  monto: number;
  fechaPromesa: string;
  lugarPago: string | null;
  fuenteIngreso: string | null;
  razonMora: string | null;
  notas: string | null;
  estatus: string;
  idGestion: number | null;
  fechaRegistro: string;
}

export interface DemograficoResumen {
  idDemografico: number;
  calle: string | null;
  colonia: string | null;
  codigoPostal: string | null;
  delegacion: string | null;
  estado: string | null;
  telefono: string | null;
  email: string | null;
  fechaRegistro: string;
}

export interface SolicitudCuenta {
  idControlLegacy: number;
  numeroCuenta: string;
  nombreCliente?: string | null;
  situacionCuenta?: string | null;
  razonMora?: string | null;
  saldo?: number | null;
}

export interface SolicitudTelefono {
  numero: string;
  tipo?: string | null;
  calificacion?: number | null;
  origen?: string | null;
}

export interface SolicitudGestion {
  idCuenta: number;
  idTipoGestion: number;
  comentario?: string | null;
  idTelefono?: number | null;
  telefonoMarcado?: string | null;
  inbound: boolean;
  tiempoLlamadaSegundos?: number | null;
  tiempoEscrituraSegundos?: number | null;
}

export interface SolicitudPromesa {
  idCuenta: number;
  idGestion?: number | null;
  monto: number;
  fechaPromesa: string;
  lugarPago?: string | null;
  fuenteIngreso?: string | null;
  razonMora?: string | null;
  notas?: string | null;
}

export interface ResultadoOperacion {
  id: number;
  mensaje: string;
}
