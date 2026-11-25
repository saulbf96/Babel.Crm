import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { Cartera } from '../catalogos/catalogos.models';
import {
  OperativoResumen,
  PersonalCartera,
  ResultadoAsignacion,
  ResultadoRestauracion,
} from './carteras.models';

/** Carteras, personal y operativo contra /api/carteras. */
@Injectable({ providedIn: 'root' })
export class CarterasService {
  private readonly http = inject(HttpClient);

  consultar(): Promise<Cartera[]> {
    return firstValueFrom(this.http.get<Cartera[]>('/api/carteras'));
  }

  personal(idCartera: number, texto?: string): Promise<PersonalCartera[]> {
    let params = new HttpParams();
    if (texto) params = params.set('texto', texto);
    return firstValueFrom(
      this.http.get<PersonalCartera[]>(`/api/carteras/${idCartera}/personal`, { params }),
    );
  }

  asignar(
    idCartera: number,
    idsEmpleados: number[],
    idDepartamento: number | null,
    operativo: boolean,
  ): Promise<ResultadoAsignacion> {
    return firstValueFrom(
      this.http.post<ResultadoAsignacion>(`/api/carteras/${idCartera}/asignar`, {
        idsEmpleados,
        idDepartamento,
        operativo,
      }),
    );
  }

  restaurar(idsEmpleados: number[]): Promise<ResultadoRestauracion> {
    return firstValueFrom(
      this.http.post<ResultadoRestauracion>('/api/carteras/restaurar', { idsEmpleados }),
    );
  }

  operativo(idCartera?: number, idEmpleado?: number): Promise<OperativoResumen[]> {
    let params = new HttpParams();
    if (idCartera != null) params = params.set('idCartera', idCartera);
    if (idEmpleado != null) params = params.set('idEmpleado', idEmpleado);
    return firstValueFrom(
      this.http.get<OperativoResumen[]>('/api/carteras/operativo', { params }),
    );
  }
}
