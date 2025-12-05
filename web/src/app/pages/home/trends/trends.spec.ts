import { ComponentFixture, TestBed } from '@angular/core/testing';

import { Trends } from './trends';

describe('Trends', () => {
  let component: Trends;
  let fixture: ComponentFixture<Trends>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [Trends]
    })
    .compileComponents();

    fixture = TestBed.createComponent(Trends);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
