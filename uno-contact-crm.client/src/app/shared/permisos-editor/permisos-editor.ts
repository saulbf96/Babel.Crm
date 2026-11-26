import { Component, computed, input, model } from '@angular/core';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatSelectChange, MatSelectModule } from '@angular/material/select';
import { OpcionPermiso } from '../../core/permisos/permisos.service';

interface Grupo {
  nombre: string;
  opciones: OpcionPermiso[];
}

/** Valor especial de la opción "Todo el menú". */
const TODO = '__todo__';

/**
 * Permisos como listas desplegables: una por menú (Gestión, Herramientas, Administración…).
 * En cada lista: "Todo el menú" o solo algunas opciones. Las opciones que quien edita NO tiene
 * se ven en gris (no puede dar ni quitar lo que no tiene; ROOT puede todo).
 */
@Component({
  selector: 'app-permisos-editor',
  imports: [MatFormFieldModule, MatSelectModule],
  template: `
    <div class="permisos">
      @for (g of grupos(); track g.nombre) {
        <mat-form-field appearance="outline" class="grupo" subscriptSizing="dynamic">
          <mat-label>{{ g.nombre }}</mat-label>
          <mat-select
            multiple
            [value]="valorDe(g)"
            [disabled]="deshabilitado() || !algunaEditable(g)"
            (selectionChange)="cambiar(g, $event)"
            panelClass="panel-permisos"
          >
            <mat-select-trigger>{{ resumen(g) }}</mat-select-trigger>
            @if (g.opciones.length > 1) {
              <mat-option [value]="todo" class="opcion-todo">Todo el menú</mat-option>
            }
            @for (o of g.opciones; track o.clave) {
              <mat-option [value]="o.clave" [disabled]="!editable(o.clave)">{{ o.titulo }}</mat-option>
            }
          </mat-select>
        </mat-form-field>
      }
    </div>
  `,
  styles: `
    .permisos {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(12rem, 1fr));
      gap: 0 1rem;
      --mat-form-field-container-height: 44px;
      --mat-form-field-container-vertical-padding: 10px;
      --mat-select-trigger-text-size: 14px;
    }
  `,
})
export class PermisosEditor {
  readonly opciones = input.required<OpcionPermiso[]>();
  /** Claves marcadas (permisos que tendrá). */
  readonly seleccionados = model<string[]>([]);
  /** Claves que quien edita puede cambiar; null = todas (ROOT). */
  readonly editables = input<ReadonlySet<string> | null>(null);
  readonly deshabilitado = input(false);

  protected readonly todo = TODO;

  protected readonly grupos = computed<Grupo[]>(() => {
    const mapa = new Map<string, OpcionPermiso[]>();
    for (const o of this.opciones()) {
      if (!mapa.has(o.grupo)) mapa.set(o.grupo, []);
      mapa.get(o.grupo)!.push(o);
    }
    return [...mapa].map(([nombre, opciones]) => ({ nombre, opciones }));
  });

  private readonly marcados = computed(() => new Set(this.seleccionados()));

  protected editable(clave: string): boolean {
    const e = this.editables();
    return e === null || e.has(clave);
  }

  protected algunaEditable(g: Grupo): boolean {
    return g.opciones.some((o) => this.editable(o.clave));
  }

  private marcadasDe(g: Grupo): string[] {
    return g.opciones.filter((o) => this.marcados().has(o.clave)).map((o) => o.clave);
  }

  /** Valor de la lista: sus opciones marcadas (+ "Todo el menú" si están todas). */
  protected valorDe(g: Grupo): string[] {
    const m = this.marcadasDe(g);
    return m.length === g.opciones.length && g.opciones.length > 1 ? [TODO, ...m] : m;
  }

  protected resumen(g: Grupo): string {
    const n = this.marcadasDe(g).length;
    if (n === 0) return 'Ninguno';
    if (n === g.opciones.length) return g.opciones.length > 1 ? 'Todo el menú' : 'Sí';
    return `${n} de ${g.opciones.length}`;
  }

  protected cambiar(g: Grupo, e: MatSelectChange): void {
    const nuevo = new Set<string>(e.value as string[]);
    const antesTodo = this.valorDe(g).includes(TODO);
    const ahoraTodo = nuevo.has(TODO);
    nuevo.delete(TODO);

    // "Todo el menú": marca o desmarca todas las opciones que quien edita puede cambiar.
    if (ahoraTodo && !antesTodo) g.opciones.filter((o) => this.editable(o.clave)).forEach((o) => nuevo.add(o.clave));
    if (!ahoraTodo && antesTodo) g.opciones.filter((o) => this.editable(o.clave)).forEach((o) => nuevo.delete(o.clave));

    const s = new Set(this.seleccionados());
    for (const o of g.opciones) {
      if (!this.editable(o.clave)) continue; // lo que no puede cambiar se queda como estaba
      if (nuevo.has(o.clave)) s.add(o.clave);
      else s.delete(o.clave);
    }
    this.seleccionados.set([...s]);
  }
}
