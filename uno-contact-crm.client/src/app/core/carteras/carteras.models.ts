/** Personal y resultados de la pantalla "Asignar personal a cartera". */
export interface PersonalCartera {
  idEmpleado: number;
  nombreCompleto: string;
  idPuesto: number;
  puesto: string;
  idDepartamento: number;
  departamento: string;
  idCartera: number | null;
  cartera: string | null;
  asignado: boolean;
  operativo: boolean;
  idAreaDep: number;
  idSegmento: number;
  idProducto: number;
  idCampana: number;
}

export interface ResultadoAsignacion {
  asignados: number;
  omitidos: number;
  mensaje: string;
}

export interface ResultadoRestauracion {
  restaurados: number;
  mensaje: string;
}

export interface OperativoResumen {
  idRegistro: number;
  idEmpleado: number;
  nombreCompleto: string;
  idAreaDep: number;
  area: string;
  idCartera: number;
  cartera: string;
  idSegmento: number;
  idProducto: number;
  idCampana: number;
  fechaRegistro: string;
}
