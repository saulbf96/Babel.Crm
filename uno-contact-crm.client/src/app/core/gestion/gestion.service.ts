import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import {
  CuentaDetalle,
  CuentaResumen,
  DemograficoResumen,
  GestionResumen,
  PromesaResumen,
  ResultadoOperacion,
  SolicitudCuenta,
  SolicitudGestion,
  SolicitudPromesa,
  SolicitudTelefono,
  TelefonoResumen,
  TipoGestion,
} from './gestion.models';

/** Gestión de cartera contra /api/gestion. La cartera la impone la sesión. */
@Injectable({ providedIn: 'root' })
export class GestionService {
  private readonly http = inject(HttpClient);

  tipos(): Promise<TipoGestion[]> {
    return firstValueFrom(this.http.get<TipoGestion[]>('/api/gestion/tipos'));
  }

  consultarCuentas(texto?: string): Promise<CuentaResumen[]> {
    let params = new HttpParams();
    if (texto) params = params.set('texto', texto);
    return firstValueFrom(this.http.get<CuentaResumen[]>('/api/gestion/cuentas', { params }));
  }

  crearCuenta(solicitud: SolicitudCuenta): Promise<ResultadoOperacion> {
    return firstValueFrom(this.http.post<ResultadoOperacion>('/api/gestion/cuentas', solicitud));
  }

  cuenta(idCuenta: number): Promise<CuentaDetalle> {
    return firstValueFrom(this.http.get<CuentaDetalle>(`/api/gestion/cuentas/${idCuenta}`));
  }

  telefonos(idCuenta: number): Promise<TelefonoResumen[]> {
    return firstValueFrom(this.http.get<TelefonoResumen[]>(`/api/gestion/cuentas/${idCuenta}/telefonos`));
  }

  registrarTelefono(idCuenta: number, solicitud: SolicitudTelefono): Promise<ResultadoOperacion> {
    return firstValueFrom(
      this.http.post<ResultadoOperacion>(`/api/gestion/cuentas/${idCuenta}/telefonos`, solicitud),
    );
  }

  gestiones(idCuenta: number): Promise<GestionResumen[]> {
    return firstValueFrom(this.http.get<GestionResumen[]>(`/api/gestion/cuentas/${idCuenta}/gestiones`));
  }

  registrarGestion(solicitud: SolicitudGestion): Promise<ResultadoOperacion> {
    return firstValueFrom(
      this.http.post<ResultadoOperacion>(
        `/api/gestion/cuentas/${solicitud.idCuenta}/gestiones`,
        solicitud,
      ),
    );
  }

  promesas(idCuenta: number): Promise<PromesaResumen[]> {
    return firstValueFrom(this.http.get<PromesaResumen[]>(`/api/gestion/cuentas/${idCuenta}/promesas`));
  }

  registrarPromesa(solicitud: SolicitudPromesa): Promise<ResultadoOperacion> {
    return firstValueFrom(
      this.http.post<ResultadoOperacion>(
        `/api/gestion/cuentas/${solicitud.idCuenta}/promesas`,
        solicitud,
      ),
    );
  }

  demograficos(idCuenta: number): Promise<DemograficoResumen[]> {
    return firstValueFrom(
      this.http.get<DemograficoResumen[]>(`/api/gestion/cuentas/${idCuenta}/demograficos`),
    );
  }
}
