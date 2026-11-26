import { Injectable, Signal, computed, signal } from '@angular/core';
import { MatPaginatorIntl, PageEvent } from '@angular/material/paginator';
import { Subject } from 'rxjs';

/** Tamaños de página que se ofrecen en todas las tablas. */
export const TAMANOS_PAGINA = [25, 50, 100];

/**
 * Paginación en el navegador sobre una lista que ya se cargó (signal).
 * Uso en la plantilla:
 *   <table mat-table [dataSource]="pag.pagina()"> ...
 *   <mat-paginator [length]="pag.total()" [pageIndex]="pag.indice()" [pageSize]="pag.tamano()"
 *                  [pageSizeOptions]="tamanos" (page)="pag.cambiar($event)" showFirstLastButtons />
 */
export class Paginacion<T> {
  readonly indice = signal(0);
  readonly tamano = signal(TAMANOS_PAGINA[0]);

  readonly total = computed(() => this.fuente().length);

  /** Renglones de la página actual. Si la lista se achicó, regresa a la primera página. */
  /** Posición (base 0) del primer renglón de la página actual. */
  private readonly desde = computed(() => {
    const tamano = this.tamano();
    const indice = this.indice() * tamano < this.fuente().length ? this.indice() : 0;
    return indice * tamano;
  });

  readonly pagina = computed(() => this.fuente().slice(this.desde(), this.desde() + this.tamano()));

  /** Número consecutivo para mostrar (1, 2, 3…; la página 2 de 25 empieza en 26). En lugar del ID interno. */
  numero(indiceEnPagina: number): number {
    return this.desde() + indiceEnPagina + 1;
  }

  constructor(private readonly fuente: Signal<T[]>) {}

  cambiar(evento: PageEvent): void {
    this.tamano.set(evento.pageSize);
    this.indice.set(evento.pageIndex);
  }

  /** Volver a la primera página (al buscar de nuevo). */
  reiniciar(): void {
    this.indice.set(0);
  }
}

/** Proveedor para cada pantalla con paginador: textos en español (no se carga en el arranque). */
export const PAGINADOR_EN_ESPANOL = [{ provide: MatPaginatorIntl, useFactory: () => new PaginadorEnEspanol() }];

/** Textos del paginador en español. */
@Injectable()
export class PaginadorEnEspanol extends MatPaginatorIntl {
  override readonly changes = new Subject<void>();
  override itemsPerPageLabel = 'Renglones por página';
  override nextPageLabel = 'Página siguiente';
  override previousPageLabel = 'Página anterior';
  override firstPageLabel = 'Primera página';
  override lastPageLabel = 'Última página';
  override getRangeLabel = (pagina: number, tamano: number, total: number): string => {
    if (total === 0) return '0 de 0';
    const desde = pagina * tamano + 1;
    const hasta = Math.min(total, (pagina + 1) * tamano);
    return `${desde} – ${hasta} de ${total}`;
  };
}
