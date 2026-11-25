import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { Catalogos } from './catalogos.models';

/** Catálogos para los combos de Administración. */
@Injectable({ providedIn: 'root' })
export class CatalogosService {
  private readonly http = inject(HttpClient);

  consultar(): Promise<Catalogos> {
    return firstValueFrom(this.http.get<Catalogos>('/api/catalogos'));
  }
}
