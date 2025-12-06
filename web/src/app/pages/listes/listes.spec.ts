import { ComponentFixture, TestBed } from '@angular/core/testing';

import { Listes } from './listes';

describe('Listes', () => {
  let component: Listes;
  let fixture: ComponentFixture<Listes>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [Listes]
    })
    .compileComponents();

    fixture = TestBed.createComponent(Listes);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
