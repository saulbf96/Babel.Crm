/** Catálogos que comparten las pantallas de Administración. */
export interface Cartera {
  idCartera: number;
  nombre: string;
  idCliente: number;
  cliente: string;
  idBaseLegacy: number | null;
  idDepartamento: number | null;
}

export interface Puesto {
  idPuesto: number;
  nombre: string;
  tipo: string;
  gerarquia: number;
}

export interface Departamento {
  idDepartamento: number;
  nombre: string;
  tipo: string;
}

export interface Sexo {
  idSexo: number;
  nombre: string;
}

export interface Turno {
  idTurno: number;
  nombre: string;
}

export interface Catalogos {
  carteras: Cartera[];
  puestos: Puesto[];
  departamentos: Departamento[];
  sexos: Sexo[];
  turnos: Turno[];
}
