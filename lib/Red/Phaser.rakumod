#| Define Red phasers
module Red::Phaser {
    # Define these here rather than next to the traits
    # as they will be used in several places
    role BeforeCreate is export { }
    role AfterCreate  is export { }
    role BeforeUpdate is export { }
    role AfterUpdate  is export { }
    role BeforeDelete is export { }
    role AfterDelete  is export { }
}
