//
//  Node.swift
//  Demangling
//
//  Created by spacefrog on 2021/03/26.
//

import Foundation

final class Node {
    
    typealias IndexType = UInt64
    
    private weak var parent: Node?
    
    private(set) var kind: Kind
    private(set) var payload: Payload
    private(set) var _children: [Node] {
        didSet {
            _children.forEach({ $0.parent = self })
        }
    }
    
    var copyOfChildren: [Node] { _children }
    
    fileprivate var numberOfParent: Int {
        var count = 0
        var parent: Node? = self.parent
        while parent != nil {
            count += 1
            parent = parent?.parent
        }
        return count
    }
    
    var numberOfChildren: Int { _children.count }
    
    init(kind: Kind) {
        self.kind = kind
        self.payload = .none
        self._children = []
    }
    
    convenience init(_ kind: Kind) {
        self.init(kind: kind)
    }
    
    init(kind: Kind, text: String) {
        self.kind = kind
        self.payload = .text(text)
        self._children = []
    }
    
    convenience init(_ kind: Kind, _ character: Character) {
        self.init(kind: kind, text: character.description)
    }
    
    init(kind: Kind, functionParamKind: FunctionSigSpecializationParamKind.Kind) {
        self.kind = kind
        self.payload = .functionSigSpecializationParamKind(.init(kind: functionParamKind))
        self._children = []
    }
    
    init(kind: Kind, functionParamOption: FunctionSigSpecializationParamKind.OptionSet) {
        self.kind = kind
        self.payload = .functionSigSpecializationParamKind(.init(optionSet: functionParamOption))
        self._children = []
    }
    
    init<N>(kind: Kind, index: N) where N: BinaryInteger {
        self.kind = kind
        self.payload = .index(UInt64(truncatingIfNeeded: index))
        self._children = []
    }
    
    convenience init<N>(_ kind: Kind, _ index: N) where N: BinaryInteger {
        self.init(kind: kind, index: index)
    }
    
    init(kind: Kind, payload: Payload) {
        self.kind = kind
        self.payload = payload
        self._children = []
    }
    
    convenience init(_ kind: Kind, _ payload: Payload) {
        self.init(kind: kind, payload: payload)
    }
    
    init(kind: Kind, children: Node?...) {
        self.kind = kind
        self.payload = .none
        self._children = children.flatten()
        self.updatePayloadForChildren()
    }
    
    convenience init(kind: Kind, child: Node?) {
        self.init(kind: kind, children: child)
    }
    
    func newNode(_ kind: Kind) -> Node {
        let node = Node(kind: kind)
        node.payload = payload
        node._children = _children
        return node
    }
    
    func children(_ at: Int) -> Node {
        if at < self._children.count {
            return self._children[at]
        } else {
            assertionFailure()
            return Node(kind: .UnknownIndex)
        }
    }
    
    func childIf(_ kind: Node.Kind) -> Node? {
        _children.first(where: { $0.kind == kind })
    }
    
    private func updatePayloadForChildren() {
        switch self._children.count {
        case 1:
            payload = .onechild
        case 2:
            payload = .twochildren
        case 3...:
            payload = .manychildren
        default:
            payload = .none
        }
    }
    
    func add(_ child: Node) {
        if payload.isChildren {
            self._children.append(child)
            self.updatePayloadForChildren()
        } else {
            assertionFailure("cannot add child to \(self)")
        }
    }
    
    func add(_ childOrNil: Node?) {
        guard let child = childOrNil else { return }
        self.add(child)
    }
    
    func add(_ kind: Node.Kind) {
        add(.init(kind: kind))
    }
    
    func add(kind: Node.Kind, text: String) {
        add(.init(kind: kind, text: text))
    }
    
    func add(kind: Node.Kind, payload: Payload) {
        add(Node(kind: kind, payload: payload))
    }
    
    func adds<C>(_ children: C) where C: Collection, C.Element == Node {
        guard children.isNotEmpty else { return }
        if payload.isChildren {
            self._children.append(contentsOf: children)
            self.updatePayloadForChildren()
        } else {
            assertionFailure("cannot add child to \(self)")
        }
    }
    
    func addFunctionSigSpecializationParamKind(kind: FunctionSigSpecializationParamKind.Kind, texts: String...) {
        add(Node(kind: .FunctionSignatureSpecializationParamKind, functionParamKind: kind))
        for text in texts {
            add(Node(kind: .FunctionSignatureSpecializationParamPayload, text: text))
        }
    }
    
    func adding(_ children: Node?...) -> Self {
        self.adding(children.flatten())
    }
    
    func adding(_ children: [Node]) -> Self {
        self.adds(children)
        return self
    }
    
    func remove(_ child: Node) {
        if let index = _children.firstIndex(where: { $0 === child }) {
            self._children.remove(at: index)
        }
    }
    
    func remove(_ at: Int) {
        guard at < numberOfChildren else { return }
        self._children.remove(at: at)
    }
    
    func reverseChildren() {
        _children.reverse()
    }
    
    func reverseChildren(_ fromAt: Int) {
        guard fromAt < numberOfChildren else { return }
        if fromAt == 0 {
            _children.reverse()
        } else {
            let prefix = _children[0..<fromAt]
            let reversedSuffix = _children[fromAt..<_children.count].reversed()
            self._children = Array(prefix) + reversedSuffix
        }
    }
    
    func replaceLast(_ child: Node) {
        self._children.removeLast()
        self._children.append(child)
    }
    
    var isSwiftModule: Bool {
        kind == .Module && text == .STDLIB_NAME
    }
    
    func isIdentifier(desired: String) -> Bool {
        kind == .Identifier && text == desired
    }
    
    var text: String {
        if case let .text(text) = self.payload {
            return text
        } else {
            return ""
        }
    }
    
    var hasText: Bool {
        self.payload.isText
    }
    
    var index: UInt64? {
        switch self.payload {
        case let .index(index):
            return index
        default:
            return nil
        }
    }
    
    var functionSigSpecializationParamKind: FunctionSigSpecializationParamKind? {
        switch self.payload {
        case let .functionSigSpecializationParamKind(kind):
            return kind
        default:
            return nil
        }
    }
    
    var valueWitnessKind: ValueWitnessKind? {
        switch self.payload {
        case let .valueWitnessKind(w):
            return w
        default:
            return nil
        }
    }
    
    var mangledDifferentiabilityKind: MangledDifferentiabilityKind? {
        switch self.payload {
        case let .mangledDifferentiabilityKind(kind):
            return kind
        case let .text(text):
            return MangledDifferentiabilityKind(rawValue: text)
        default:
            return nil
        }
    }
    
    var firstChild: Node {
        children(0)
    }
    
    var lastChild: Node {
        children(_children.endIndex - 1)
    }
    
    var directness: Directness {
        if case let .directness(directness) = self.payload {
            return directness
        } else {
            assertionFailure()
            return .unknown
        }
    }
}

// MARK: Type
extension Node {
    var isNeedSpaceBeforeType: Bool {
        switch kind {
        case .Type:
            return firstChild.isNeedSpaceBeforeType
        case .FunctionType,
                .NoEscapeFunctionType,
                .UncurriedFunctionType,
                .DependentGenericType:
            return false
        default:
            return true
        }
    }
    
    var isSimpleType: Bool {
        switch kind {
        case .AssociatedType,
                .AssociatedTypeRef,
                .BoundGenericClass,
                .BoundGenericEnum,
                .BoundGenericStructure,
                .BoundGenericProtocol,
                .BoundGenericOtherNominalType,
                .BoundGenericTypeAlias,
                .BoundGenericFunction,
                .BuiltinTypeName,
                .BuiltinTupleType,
                .BuiltinFixedArray,
                .Class,
                .DependentGenericType,
                .DependentMemberType,
                .DependentGenericParamType,
                .DynamicSelf,
                .Enum,
                .ErrorType,
                .ExistentialMetatype,
                .Metatype,
                .MetatypeRepresentation,
                .Module,
                .Tuple,
                .Pack,
                .SILPackDirect,
                .SILPackIndirect,
                .ConstrainedExistentialRequirementList,
                .ConstrainedExistentialSelf,
                .Protocol,
                .ProtocolSymbolicReference,
                .ReturnType,
                .SILBoxType,
                .SILBoxTypeWithLayout,
                .Structure,
                .OtherNominalType,
                .TupleElementName,
                .TypeAlias,
                .TypeList,
                .LabelList,
                .TypeSymbolicReference,
                .SugaredOptional,
                .SugaredArray,
                .SugaredDictionary,
                .SugaredParen,
                .Integer,
                .NegativeInteger:
            return true
        case .Type:
            return firstChild.isSimpleType
        case .ProtocolList:
            return _children[0].numberOfChildren <= 1
        case .ProtocolListWithAnyObject:
            return _children[0]._children[0].numberOfChildren == 0
        case .ConstrainedExistential,
                .PackElement,
                .PackElementLevel,
                .PackExpansion,
                .ProtocolListWithClass,
                .AccessorAttachedMacroExpansion,
                .AccessorFunctionReference,
                .Allocator,
                .ArgumentTuple,
                .AssociatedConformanceDescriptor,
                .AssociatedTypeDescriptor,
                .AssociatedTypeMetadataAccessor,
                .AssociatedTypeWitnessTableAccessor,
                .AsyncRemoved,
                .AutoClosureType,
                .BaseConformanceDescriptor,
                .BaseWitnessTableAccessor,
                .BodyAttachedMacroExpansion,
                .ClangType,
                .ClassMetadataBaseOffset,
                .CFunctionPointer,
                .ConformanceAttachedMacroExpansion,
                .Constructor,
                .CoroutineContinuationPrototype,
                .CurryThunk,
                .SILThunkIdentity,
                .SILThunkHopToMainActorIfNeeded,
                .DispatchThunk,
                .Deallocator,
                .IsolatedDeallocator,
                .DeclContext,
                .DefaultArgumentInitializer,
                .DefaultAssociatedTypeMetadataAccessor,
                .DefaultAssociatedConformanceAccessor,
                .DependentAssociatedTypeRef,
                .DependentGenericSignature,
                .DependentGenericParamPackMarker,
                .DependentGenericParamCount,
                .DependentGenericConformanceRequirement,
                .DependentGenericLayoutRequirement,
                .DependentGenericSameTypeRequirement,
                .DependentGenericSameShapeRequirement,
                .DependentPseudogenericSignature,
                .Destructor,
                .DidSet,
                .DirectMethodReferenceAttribute,
                .Directness,
                .DynamicAttribute,
                .EscapingAutoClosureType,
                .EscapingObjCBlock,
                .NoEscapeFunctionType,
                .ExplicitClosure,
                .Extension,
                .ExtensionAttachedMacroExpansion,
                .EnumCase,
                .FieldOffset,
                .FreestandingMacroExpansion,
                .FullObjCResilientClassStub,
                .FullTypeMetadata,
                .Function,
                .FunctionSignatureSpecialization,
                .FunctionSignatureSpecializationParam,
                .FunctionSignatureSpecializationReturn,
                .FunctionSignatureSpecializationParamKind,
                .FunctionSignatureSpecializationParamPayload,
                .FunctionType,
                .GenericProtocolWitnessTable,
                .GenericProtocolWitnessTableInstantiationFunction,
                .GenericPartialSpecialization,
                .GenericPartialSpecializationNotReAbstracted,
                .GenericSpecialization,
                .GenericSpecializationNotReAbstracted,
                .GenericSpecializationInResilienceDomain,
                .GenericSpecializationParam,
                .GenericSpecializationPrespecialized,
                .InlinedGenericFunction,
                .GenericTypeMetadataPattern,
                .Getter,
                .Global,
                .GlobalGetter,
                .Identifier,
                .Index,
                .InitAccessor,
                .IVarInitializer,
                .IVarDestroyer,
                .ImplDifferentiabilityKind,
                .ImplEscaping,
                .ImplErasedIsolation,
                .ImplSendingResult,
                .ImplConvention,
                .ImplParameterResultDifferentiability,
                .ImplParameterSending,
                .ImplFunctionAttribute,
                .ImplFunctionConvention,
                .ImplFunctionConventionName,
                .ImplFunctionType,
                .ImplCoroutineKind,
                .ImplInvocationSubstitutions,
                .ImplPatternSubstitutions,
                .ImplicitClosure,
                .ImplParameter,
                .ImplResult,
                .ImplYield,
                .ImplErrorResult,
                .InOut,
                .InfixOperator,
                .Initializer,
                .Isolated,
                .Sending,
                .CompileTimeConst,
                .PropertyWrapperBackingInitializer,
                .PropertyWrapperInitFromProjectedValue,
                .KeyPathGetterThunkHelper,
                .KeyPathSetterThunkHelper,
                .KeyPathEqualsThunkHelper,
                .KeyPathHashThunkHelper,
                .LazyProtocolWitnessTableAccessor,
                .LazyProtocolWitnessTableCacheVariable,
                .LocalDeclName,
                .Macro,
                .MacroExpansionLoc,
                .MacroExpansionUniqueName,
                .MaterializeForSet,
                .MemberAttributeAttachedMacroExpansion,
                .MemberAttachedMacroExpansion,
                .MergedFunction,
                .Metaclass,
                .MethodDescriptor,
                .MethodLookupFunction,
                .ModifyAccessor,
                .Modify2Accessor,
                .NativeOwningAddressor,
                .NativeOwningMutableAddressor,
                .NativePinningAddressor,
                .NativePinningMutableAddressor,
                .NominalTypeDescriptor,
                .NominalTypeDescriptorRecord,
                .NonObjCAttribute,
                .Number,
                .ObjCAsyncCompletionHandlerImpl,
                .ObjCAttribute,
                .ObjCBlock,
                .ObjCMetadataUpdateFunction,
                .ObjCResilientClassStub,
                .OpaqueTypeDescriptor,
                .OpaqueTypeDescriptorRecord,
                .OpaqueTypeDescriptorAccessor,
                .OpaqueTypeDescriptorAccessorImpl,
                .OpaqueTypeDescriptorAccessorKey,
                .OpaqueTypeDescriptorAccessorVar,
                .Owned,
                .OwningAddressor,
                .OwningMutableAddressor,
                .PartialApplyForwarder,
                .PartialApplyObjCForwarder,
                .PeerAttachedMacroExpansion,
                .PostfixOperator,
                .PreambleAttachedMacroExpansion,
                .PredefinedObjCAsyncCompletionHandlerImpl,
                .PrefixOperator,
                .PrivateDeclName,
                .PropertyDescriptor,
                .ProtocolConformance,
                .ProtocolConformanceDescriptor,
                .ProtocolConformanceDescriptorRecord,
                .MetadataInstantiationCache,
                .ProtocolDescriptor,
                .ProtocolDescriptorRecord,
                .ProtocolRequirementsBaseDescriptor,
                .ProtocolSelfConformanceDescriptor,
                .ProtocolSelfConformanceWitness,
                .ProtocolSelfConformanceWitnessTable,
                .ProtocolWitness,
                .ProtocolWitnessTable,
                .ProtocolWitnessTableAccessor,
                .ProtocolWitnessTablePattern,
                .ReabstractionThunk,
                .ReabstractionThunkHelper,
                .ReabstractionThunkHelperWithSelf,
                .ReabstractionThunkHelperWithGlobalActor,
                .ReadAccessor,
                .Read2Accessor,
                .RelatedEntityDeclName,
                .RetroactiveConformance,
                .Setter,
                .Shared,
                .SILBoxLayout,
                .SILBoxMutableField,
                .SILBoxImmutableField,
                .IsSerialized,
                .DroppedArgument,
                .SpecializationPassID,
                .Static,
                .Subscript,
                .Suffix,
                .ThinFunctionType,
                .TupleElement,
                .TypeMangling,
                .TypeMetadata,
                .TypeMetadataAccessFunction,
                .TypeMetadataCompletionFunction,
                .TypeMetadataInstantiationCache,
                .TypeMetadataInstantiationFunction,
                .TypeMetadataSingletonInitializationCache,
                .TypeMetadataDemanglingCache,
                .TypeMetadataLazyCache,
                .UncurriedFunctionType,
                .Weak,
                .Unowned,
                .Unmanaged,
                .UnknownIndex,
                .UnsafeAddressor,
                .UnsafeMutableAddressor,
                .ValueWitness,
                .ValueWitnessTable,
                .Variable,
                .VTableAttribute,
                .VTableThunk,
                .WillSet,
                .ReflectionMetadataBuiltinDescriptor,
                .ReflectionMetadataFieldDescriptor,
                .ReflectionMetadataAssocTypeDescriptor,
                .ReflectionMetadataSuperclassDescriptor,
                .ResilientProtocolWitnessTable,
                .GenericTypeParamDecl,
                .ConcurrentFunctionType,
                .DifferentiableFunctionType,
                .GlobalActorFunctionType,
                .IsolatedAnyFunctionType,
                .SendingResultFunctionType,
                .AsyncAnnotation,
                .ThrowsAnnotation,
                .TypedThrowsAnnotation,
                .EmptyList,
                .FirstElementMarker,
                .VariadicMarker,
                .OutlinedBridgedMethod,
                .OutlinedCopy,
                .OutlinedConsume,
                .OutlinedRetain,
                .OutlinedRelease,
                .OutlinedInitializeWithTake,
                .OutlinedInitializeWithCopy,
                .OutlinedAssignWithTake,
                .OutlinedAssignWithCopy,
                .OutlinedDestroy,
                .OutlinedInitializeWithCopyNoValueWitness,
                .OutlinedAssignWithTakeNoValueWitness,
                .OutlinedAssignWithCopyNoValueWitness,
                .OutlinedDestroyNoValueWitness,
                .OutlinedEnumTagStore,
                .OutlinedEnumGetTag,
                .OutlinedEnumProjectDataForLoad,
                .OutlinedVariable,
                .OutlinedReadOnlyObject,
                .AssocTypePath,
                .ModuleDescriptor,
                .AnonymousDescriptor,
                .AssociatedTypeGenericParamRef,
                .ExtensionDescriptor,
                .AnonymousContext,
                .AnyProtocolConformanceList,
                .ConcreteProtocolConformance,
                .PackProtocolConformance,
                .DependentAssociatedConformance,
                .DependentProtocolConformanceAssociated,
                .DependentProtocolConformanceInherited,
                .DependentProtocolConformanceRoot,
                .ProtocolConformanceRefInTypeModule,
                .ProtocolConformanceRefInProtocolModule,
                .ProtocolConformanceRefInOtherModule,
                .DistributedThunk,
                .DistributedAccessor,
                .DynamicallyReplaceableFunctionKey,
                .DynamicallyReplaceableFunctionImpl,
                .DynamicallyReplaceableFunctionVar,
                .OpaqueType,
                .OpaqueTypeDescriptorSymbolicReference,
                .OpaqueReturnType,
                .OpaqueReturnTypeIndex,
                .OpaqueReturnTypeParent,
                .OpaqueReturnTypeOf,
                .CanonicalSpecializedGenericMetaclass,
                .CanonicalSpecializedGenericTypeMetadataAccessFunction,
                .NoncanonicalSpecializedGenericTypeMetadata,
                .NoncanonicalSpecializedGenericTypeMetadataCache,
                .GlobalVariableOnceDeclList,
                .GlobalVariableOnceFunction,
                .GlobalVariableOnceToken,
                .CanonicalPrespecializedGenericTypeCachingOnceToken,
                .AsyncFunctionPointer,
                .AutoDiffFunction,
                .AutoDiffDerivativeVTableThunk,
                .AutoDiffSelfReorderingReabstractionThunk,
                .AutoDiffSubsetParametersThunk,
                .AutoDiffFunctionKind,
                .DifferentiabilityWitness,
                .NoDerivative,
                .IndexSubset,
                .AsyncAwaitResumePartialFunction,
                .AsyncSuspendResumePartialFunction,
                .AccessibleFunctionRecord,
                .BackDeploymentThunk,
                .BackDeploymentFallback,
                .ExtendedExistentialTypeShape,
                .Uniquable,
                .UniqueExtendedExistentialTypeShapeSymbolicReference,
                .NonUniqueExtendedExistentialTypeShapeSymbolicReference,
                .SymbolicExtendedExistentialType,
                .HasSymbolQuery,
                .ObjectiveCProtocolSymbolicReference,
                .DependentGenericInverseConformanceRequirement,
                .DependentGenericParamValueMarker:
            return false
        }
    }
    
    var isExistentialType: Bool {
        [Kind.ExistentialMetatype, .ProtocolList, .ProtocolListWithClass, .ProtocolListWithAnyObject].contains(kind)
    }
    
    var isClassType: Bool { kind == .Class }
    
    var isAlias: Bool {
        switch self.kind {
        case .Type:
            return firstChild.isAlias
        case .TypeAlias:
            return true
        default:
            return false
        }
    }
    
    var isClass: Bool {
        switch self.kind {
        case .Type:
            return firstChild.isClass
        case .Class, .BoundGenericClass:
            return true
        default:
            return false
        }
    }
    
    var isEnum: Bool {
        switch self.kind {
        case .Type:
            return firstChild.isEnum
        case .Enum, .BoundGenericEnum:
            return true
        default:
            return false
        }
    }
    
    var isProtocol: Bool {
        switch self.kind {
        case .Type:
            return firstChild.isProtocol
        case .Protocol, .ProtocolSymbolicReference, .ObjectiveCProtocolSymbolicReference:
            return true
        default:
            return false
        }
    }
    
    var isStruct: Bool {
        switch self.kind {
        case .Type:
            return firstChild.isStruct
        case .Structure, .BoundGenericStructure:
            return true
        default:
            return false
        }
    }
    
    var isConsumesGenericArgs: Bool {
        switch kind {
        case .Variable,
                .Subscript,
                .ImplicitClosure,
                .ExplicitClosure,
                .DefaultArgumentInitializer,
                .Initializer,
                .PropertyWrapperBackingInitializer,
                .PropertyWrapperInitFromProjectedValue:
            return false
        default:
            return true
        }
    }
    
    var isSpecialized: Bool {
        switch kind {
        case .BoundGenericStructure,.BoundGenericEnum,.BoundGenericClass,.BoundGenericOtherNominalType,.BoundGenericTypeAlias,.BoundGenericProtocol,.BoundGenericFunction:
            return true
        case .Structure, .Enum, .Class, .TypeAlias, .OtherNominalType, .Protocol, .Function, .Allocator, .Constructor, .Destructor, .Variable, .Subscript, .ExplicitClosure, .ImplicitClosure, .Initializer, .PropertyWrapperBackingInitializer, .PropertyWrapperInitFromProjectedValue, .DefaultArgumentInitializer, .Getter, .Setter, .WillSet, .DidSet, .ReadAccessor, .ModifyAccessor, .UnsafeAddressor, .UnsafeMutableAddressor:
            return firstChild.isSpecialized
        case .Extension:
            return children(1).isSpecialized
        default:
            return false
        }
    }
    
    func unspecialized() -> Node? {
        var NumToCopy = 2
        switch kind {
        case .Function, .Getter, .Setter, .WillSet, .DidSet, .ReadAccessor, .ModifyAccessor, .UnsafeAddressor, .UnsafeMutableAddressor, .Allocator, .Constructor, .Destructor, .Variable, .Subscript, .ExplicitClosure, .ImplicitClosure, .Initializer, .PropertyWrapperBackingInitializer, .PropertyWrapperInitFromProjectedValue, .DefaultArgumentInitializer:
            NumToCopy = numberOfChildren
            fallthrough
        case .Structure, .Enum, .Class, .TypeAlias, .OtherNominalType:
            let result = Node(kind)
            var parentOrModule: Node? = firstChild
            if parentOrModule?.isSpecialized == true {
                parentOrModule = parentOrModule?.unspecialized()
            }
            result.addChild(parentOrModule)
            if NumToCopy > 0 {
                for index in 0..<NumToCopy {
                    result.addChild(getChild(index))
                }
            }
            return result
            
        case .BoundGenericStructure, .BoundGenericEnum, .BoundGenericClass, .BoundGenericProtocol, .BoundGenericOtherNominalType, .BoundGenericTypeAlias:
            let unboundType = getChild(0)
            assert(unboundType.getKind() == .Type)
            let nominalType = unboundType.getChild(0)
            if nominalType.isSpecialized {
                return nominalType.unspecialized()
            }
            return nominalType
        case .BoundGenericFunction:
            let unboundFunction = getChild(0)
            assert(unboundFunction.getKind() == .Function || unboundFunction.getKind() == .Constructor)
            if unboundFunction.isSpecialized {
                return unboundFunction.unspecialized()
            }
            return unboundFunction
        case .Extension:
            let parent = getChild(1)
            if !parent.isSpecialized {
                return self
            }
            let result = Node(.Extension)
            result.addChild(firstChild)
            result.addChild(parent.unspecialized())
            if numberOfChildren == 3 {
                // Add the generic signature of the extension.
                result.addChild(getChild(2))
            }
            return result
        default:
            assertionFailure("bad nominal type kind")
        }
        return nil
    }
}

extension Node {
    public enum Payload: Equatable, CustomDebugStringConvertible {
        case none
        case text(String)
        case index(UInt64)
        case valueWitnessKind(ValueWitnessKind)
        case mangledDifferentiabilityKind(MangledDifferentiabilityKind)
        case functionSigSpecializationParamKind(FunctionSigSpecializationParamKind)
        case directness(Directness)
        case onechild
        case twochildren
        case manychildren
        
        var isChildren: Bool {
            switch self {
            case .none, .onechild, .twochildren, .manychildren:
                return true
            default:
                return false
            }
        }
        
        var isText: Bool {
            switch self {
            case .text: return true
            default: return false
            }
        }
        
        var hasValue: Bool {
            switch self {
            case .text, .index:
                return true
            default:
                return false
            }
        }
        
        public var debugDescription: String {
            switch self {
            case .text(let value):
                return "text:\"\(value)\""
            case .index(let value):
                return "index:\(value)"
            default:
                return ""
            }
        }
    }
    
    public enum Kind: String, Equatable {//}, CustomStringConvertible, CustomDebugStringConvertible {
        case Allocator
        case AnonymousContext
        case AnyProtocolConformanceList
        case ArgumentTuple
        case AssociatedType
        case AssociatedTypeRef
        case AssociatedTypeMetadataAccessor
        case DefaultAssociatedTypeMetadataAccessor
        case AccessorAttachedMacroExpansion
        case AssociatedTypeWitnessTableAccessor
        case BaseWitnessTableAccessor
        case BodyAttachedMacroExpansion
        case AutoClosureType
        case BoundGenericClass
        case BoundGenericEnum
        case BoundGenericStructure
        case BoundGenericProtocol
        case BoundGenericOtherNominalType
        case BoundGenericTypeAlias
        case BoundGenericFunction
        case BuiltinTypeName
        case BuiltinTupleType
        case BuiltinFixedArray
        case CFunctionPointer
        case ClangType
        case Class
        case ClassMetadataBaseOffset
        case ConcreteProtocolConformance
        case PackProtocolConformance
        case ConformanceAttachedMacroExpansion
        case Constructor
        case CoroutineContinuationPrototype
        case Deallocator
        case DeclContext
        case DefaultArgumentInitializer
        case DependentAssociatedConformance
        case DependentAssociatedTypeRef
        case DependentGenericConformanceRequirement
        case DependentGenericParamCount
        case DependentGenericParamType
        case DependentGenericSameTypeRequirement
        case DependentGenericSameShapeRequirement
        case DependentGenericLayoutRequirement
        case DependentGenericParamPackMarker
        case DependentGenericSignature
        case DependentGenericType
        case DependentMemberType
        case DependentPseudogenericSignature
        case DependentProtocolConformanceRoot
        case DependentProtocolConformanceInherited
        case DependentProtocolConformanceAssociated
        case Destructor
        case DidSet
        case Directness
        case DistributedThunk
        case DistributedAccessor
        case DynamicAttribute
        case DirectMethodReferenceAttribute
        case DynamicSelf
        case DynamicallyReplaceableFunctionImpl
        case DynamicallyReplaceableFunctionKey
        case DynamicallyReplaceableFunctionVar
        case Enum
        case EnumCase
        case ErrorType
        case EscapingAutoClosureType
        case NoEscapeFunctionType
        case ConcurrentFunctionType
        case GlobalActorFunctionType
        case DifferentiableFunctionType
        case ExistentialMetatype
        case ExplicitClosure
        case Extension
        case ExtensionAttachedMacroExpansion
        case FieldOffset
        case FreestandingMacroExpansion
        case FullTypeMetadata
        case Function
        case FunctionSignatureSpecialization
        case FunctionSignatureSpecializationParam
        case FunctionSignatureSpecializationReturn
        case FunctionSignatureSpecializationParamKind
        case FunctionSignatureSpecializationParamPayload
        case FunctionType
        case ConstrainedExistential
        case ConstrainedExistentialRequirementList
        case ConstrainedExistentialSelf
        case GenericPartialSpecialization
        case GenericPartialSpecializationNotReAbstracted
        case GenericProtocolWitnessTable
        case GenericProtocolWitnessTableInstantiationFunction
        case ResilientProtocolWitnessTable
        case GenericSpecialization
        case GenericSpecializationNotReAbstracted
        case GenericSpecializationInResilienceDomain
        case GenericSpecializationParam
        case GenericSpecializationPrespecialized
        case InlinedGenericFunction
        case GenericTypeMetadataPattern
        case Getter
        case Global
        case GlobalGetter
        case Identifier
        case Index
        case IVarInitializer
        case IVarDestroyer
        case ImplEscaping
        case ImplConvention
        case ImplDifferentiabilityKind
        case ImplErasedIsolation
        case ImplSendingResult
        case ImplParameterResultDifferentiability
        case ImplParameterSending
        case ImplFunctionAttribute
        case ImplFunctionConvention
        case ImplFunctionConventionName
        case ImplFunctionType
        case ImplCoroutineKind
        case ImplInvocationSubstitutions
        case ImplicitClosure
        case ImplParameter
        case ImplPatternSubstitutions
        case ImplResult
        case ImplYield
        case ImplErrorResult
        case InOut
        case InfixOperator
        case Initializer
        case InitAccessor
        case Isolated
        case IsolatedDeallocator
        case Sending
        case IsolatedAnyFunctionType
        case SendingResultFunctionType
        case KeyPathGetterThunkHelper
        case KeyPathSetterThunkHelper
        case KeyPathEqualsThunkHelper
        case KeyPathHashThunkHelper
        case LazyProtocolWitnessTableAccessor
        case LazyProtocolWitnessTableCacheVariable
        case LocalDeclName
        case Macro
        case MacroExpansionLoc
        case MacroExpansionUniqueName
        case MaterializeForSet
        case MemberAttachedMacroExpansion
        case MemberAttributeAttachedMacroExpansion
        case MergedFunction
        case Metatype
        case MetatypeRepresentation
        case Metaclass
        case MethodLookupFunction
        case ObjCMetadataUpdateFunction
        case ObjCResilientClassStub
        case FullObjCResilientClassStub
        case ModifyAccessor
        case Modify2Accessor
        case Module
        case NativeOwningAddressor
        case NativeOwningMutableAddressor
        case NativePinningAddressor
        case NativePinningMutableAddressor
        case NominalTypeDescriptor
        case NominalTypeDescriptorRecord
        case NonObjCAttribute
        case Number
        case ObjCAsyncCompletionHandlerImpl
        case PredefinedObjCAsyncCompletionHandlerImpl
        case ObjCAttribute
        case ObjCBlock
        case EscapingObjCBlock
        case OtherNominalType
        case OwningAddressor
        case OwningMutableAddressor
        case PartialApplyForwarder
        case PartialApplyObjCForwarder
        case PeerAttachedMacroExpansion
        case PostfixOperator
        case PreambleAttachedMacroExpansion
        case PrefixOperator
        case PrivateDeclName
        case PropertyDescriptor
        case PropertyWrapperBackingInitializer
        case PropertyWrapperInitFromProjectedValue
        case `Protocol`
        case ProtocolSymbolicReference
        case ProtocolConformance
        case ProtocolConformanceRefInTypeModule
        case ProtocolConformanceRefInProtocolModule
        case ProtocolConformanceRefInOtherModule
        case ProtocolDescriptor
        case ProtocolDescriptorRecord
        case ProtocolConformanceDescriptor
        case ProtocolConformanceDescriptorRecord
        case ProtocolList
        case ProtocolListWithClass
        case ProtocolListWithAnyObject
        case ProtocolSelfConformanceDescriptor
        case ProtocolSelfConformanceWitness
        case ProtocolSelfConformanceWitnessTable
        case ProtocolWitness
        case ProtocolWitnessTable
        case ProtocolWitnessTableAccessor
        case ProtocolWitnessTablePattern
        case ReabstractionThunk
        case ReabstractionThunkHelper
        case ReabstractionThunkHelperWithSelf
        case ReabstractionThunkHelperWithGlobalActor
        case ReadAccessor
        case Read2Accessor
        case RelatedEntityDeclName
        case RetroactiveConformance
        case ReturnType
        case Shared
        case Owned
        case SILBoxType
        case SILBoxTypeWithLayout
        case SILBoxLayout
        case SILBoxMutableField
        case SILBoxImmutableField
        case Setter
        case SpecializationPassID
        case IsSerialized
        case Static
        case Structure
        case Subscript
        case Suffix
        case ThinFunctionType
        case Tuple
        case TupleElement
        case TupleElementName
        case Pack
        case SILPackDirect
        case SILPackIndirect
        case PackExpansion
        case PackElement
        case PackElementLevel
        case `Type`
        case TypeSymbolicReference
        case TypeAlias
        case TypeList
        case TypeMangling
        case TypeMetadata
        case TypeMetadataAccessFunction
        case TypeMetadataCompletionFunction
        case TypeMetadataInstantiationCache
        case TypeMetadataInstantiationFunction
        case TypeMetadataSingletonInitializationCache
        case TypeMetadataDemanglingCache
        case TypeMetadataLazyCache
        case UncurriedFunctionType
        case UnknownIndex
        case Weak
        case Unowned
        case Unmanaged
        case UnsafeAddressor
        case UnsafeMutableAddressor
        case ValueWitness
        case ValueWitnessTable
        case Variable
        case VTableThunk
        /// note: old mangling only
        case VTableAttribute
        case WillSet
        case ReflectionMetadataBuiltinDescriptor
        case ReflectionMetadataFieldDescriptor
        case ReflectionMetadataAssocTypeDescriptor
        case ReflectionMetadataSuperclassDescriptor
        case GenericTypeParamDecl
        case CurryThunk
        case SILThunkIdentity
        case SILThunkHopToMainActorIfNeeded
        case DispatchThunk
        case MethodDescriptor
        case ProtocolRequirementsBaseDescriptor
        case AssociatedConformanceDescriptor
        case DefaultAssociatedConformanceAccessor
        case BaseConformanceDescriptor
        case AssociatedTypeDescriptor
        case AsyncAnnotation
        case ThrowsAnnotation
        case TypedThrowsAnnotation
        case EmptyList
        case FirstElementMarker
        case VariadicMarker
        case OutlinedBridgedMethod
        case OutlinedCopy
        case OutlinedConsume
        case OutlinedRetain
        case OutlinedRelease
        case OutlinedInitializeWithTake
        case OutlinedInitializeWithCopy
        case OutlinedAssignWithTake
        case OutlinedAssignWithCopy
        case OutlinedDestroy
        case OutlinedVariable
        case OutlinedReadOnlyObject
        case AssocTypePath
        case LabelList
        case ModuleDescriptor
        case ExtensionDescriptor
        case AnonymousDescriptor
        case AssociatedTypeGenericParamRef
        case SugaredOptional
        case SugaredArray
        case SugaredDictionary
        case SugaredParen // Removed in Swift 6.TBD
        
        // Added in Swift 5.1
        case AccessorFunctionReference
        case OpaqueType
        case OpaqueTypeDescriptorSymbolicReference
        case OpaqueTypeDescriptor
        case OpaqueTypeDescriptorRecord
        case OpaqueTypeDescriptorAccessor
        case OpaqueTypeDescriptorAccessorImpl
        case OpaqueTypeDescriptorAccessorKey
        case OpaqueTypeDescriptorAccessorVar
        case OpaqueReturnType
        case OpaqueReturnTypeOf
        
        // Added in Swift 5.4
        case CanonicalSpecializedGenericMetaclass
        case CanonicalSpecializedGenericTypeMetadataAccessFunction
        case MetadataInstantiationCache
        case NoncanonicalSpecializedGenericTypeMetadata
        case NoncanonicalSpecializedGenericTypeMetadataCache
        case GlobalVariableOnceFunction
        case GlobalVariableOnceToken
        case GlobalVariableOnceDeclList
        case CanonicalPrespecializedGenericTypeCachingOnceToken
        
        // Added in Swift 5.5
        case AsyncFunctionPointer
        case AutoDiffFunction
        case AutoDiffFunctionKind
        case AutoDiffSelfReorderingReabstractionThunk
        case AutoDiffSubsetParametersThunk
        case AutoDiffDerivativeVTableThunk
        case DifferentiabilityWitness
        case NoDerivative
        case IndexSubset
        case AsyncAwaitResumePartialFunction
        case AsyncSuspendResumePartialFunction
        
        // Added in Swift 5.6
        case AccessibleFunctionRecord
        case CompileTimeConst
        
        // Added in Swift 5.7
        case BackDeploymentThunk
        case BackDeploymentFallback
        case ExtendedExistentialTypeShape
        case Uniquable
        case UniqueExtendedExistentialTypeShapeSymbolicReference
        case NonUniqueExtendedExistentialTypeShapeSymbolicReference
        case SymbolicExtendedExistentialType
        
        // Added in Swift 5.8
        case DroppedArgument
        case HasSymbolQuery
        case OpaqueReturnTypeIndex
        case OpaqueReturnTypeParent
        
        // Addedn in Swift 6.0
        case OutlinedEnumTagStore
        case OutlinedEnumProjectDataForLoad
        case OutlinedEnumGetTag
        // Added in Swift 5.9 + 1
        case AsyncRemoved
        
        // Added in Swift 5.TBD
        case ObjectiveCProtocolSymbolicReference
        case OutlinedInitializeWithCopyNoValueWitness
        case OutlinedAssignWithTakeNoValueWitness
        case OutlinedAssignWithCopyNoValueWitness
        case OutlinedDestroyNoValueWitness
        case DependentGenericInverseConformanceRequirement
        
        // Added in Swift 6.TBD
        case Integer
        case NegativeInteger
        case DependentGenericParamValueMarker
        
        public func `in`(_ kinds: Self...) -> Bool {
            kinds.contains(self)
        }
        
    }
    
    public enum IsVariadic {
        case yes, no
    }
    
    public enum Directness {
        case direct, indirect, unknown
        
        var text: String {
            switch self {
            case .direct:
                return "direct"
            case .indirect:
                return "indirect"
            case .unknown:
                return ""
            }
        }
    }
    
    public enum ValueWitnessKind {
        case AllocateBuffer
        case AssignWithCopy
        case AssignWithTake
        case DeallocateBuffer
        case Destroy
        case DestroyBuffer
        case DestroyArray
        case InitializeBufferWithCopyOfBuffer
        case InitializeBufferWithCopy
        case InitializeWithCopy
        case InitializeBufferWithTake
        case InitializeWithTake
        case ProjectBuffer
        case InitializeBufferWithTakeOfBuffer
        case InitializeArrayWithCopy
        case InitializeArrayWithTakeFrontToBack
        case InitializeArrayWithTakeBackToFront
        case StoreExtraInhabitant
        case GetExtraInhabitantIndex
        case GetEnumTag
        case DestructiveProjectEnumData
        case DestructiveInjectEnumTag
        case GetEnumTagSinglePayload
        case StoreEnumTagSinglePayload
        
        init?(code: String) {
            switch code {
            case "al": self = .AllocateBuffer
            case "ca": self = .AssignWithCopy
            case "ta": self = .AssignWithTake
            case "de": self = .DeallocateBuffer
            case "xx": self = .Destroy
            case "XX": self = .DestroyBuffer
            case "Xx": self = .DestroyArray
            case "CP": self = .InitializeBufferWithCopyOfBuffer
            case "Cp": self = .InitializeBufferWithCopy
            case "cp": self = .InitializeWithCopy
            case "Tk": self = .InitializeBufferWithTake
            case "tk": self = .InitializeWithTake
            case "pr": self = .ProjectBuffer
            case "TK": self = .InitializeBufferWithTakeOfBuffer
            case "Cc": self = .InitializeArrayWithCopy
            case "Tt": self = .InitializeArrayWithTakeFrontToBack
            case "tT": self = .InitializeArrayWithTakeBackToFront
            case "xs": self = .StoreExtraInhabitant
            case "xg": self = .GetExtraInhabitantIndex
            case "ug": self = .GetEnumTag
            case "up": self = .DestructiveProjectEnumData
            case "ui": self = .DestructiveInjectEnumTag
            case "et": self = .GetEnumTagSinglePayload
            case "st": self = .StoreEnumTagSinglePayload
            default:
                return nil
            }
        }
        
        var name: String {
            switch self {
            case .AllocateBuffer:
                return "AllocateBuffer".lowercasedOnlyFirst()
            case .AssignWithCopy:
                return "AssignWithCopy".lowercasedOnlyFirst()
            case .AssignWithTake:
                return "AssignWithTake".lowercasedOnlyFirst()
            case .DeallocateBuffer:
                return "DeallocateBuffer".lowercasedOnlyFirst()
            case .Destroy:
                return "Destroy".lowercasedOnlyFirst()
            case .DestroyBuffer:
                return "DestroyBuffer".lowercasedOnlyFirst()
            case .DestroyArray:
                return "DestroyArray".lowercasedOnlyFirst()
            case .InitializeBufferWithCopyOfBuffer:
                return "InitializeBufferWithCopyOfBuffer".lowercasedOnlyFirst()
            case .InitializeBufferWithCopy:
                return "InitializeBufferWithCopy".lowercasedOnlyFirst()
            case .InitializeWithCopy:
                return "InitializeWithCopy".lowercasedOnlyFirst()
            case .InitializeBufferWithTake:
                return "InitializeBufferWithTake".lowercasedOnlyFirst()
            case .InitializeWithTake:
                return "InitializeWithTake".lowercasedOnlyFirst()
            case .ProjectBuffer:
                return "ProjectBuffer".lowercasedOnlyFirst()
            case .InitializeBufferWithTakeOfBuffer:
                return "InitializeBufferWithTakeOfBuffer".lowercasedOnlyFirst()
            case .InitializeArrayWithCopy:
                return "InitializeArrayWithCopy".lowercasedOnlyFirst()
            case .InitializeArrayWithTakeFrontToBack:
                return "InitializeArrayWithTakeFrontToBack".lowercasedOnlyFirst()
            case .InitializeArrayWithTakeBackToFront:
                return "InitializeArrayWithTakeBackToFront".lowercasedOnlyFirst()
            case .StoreExtraInhabitant:
                return "StoreExtraInhabitant".lowercasedOnlyFirst()
            case .GetExtraInhabitantIndex:
                return "GetExtraInhabitantIndex".lowercasedOnlyFirst()
            case .GetEnumTag:
                return "GetEnumTag".lowercasedOnlyFirst()
            case .DestructiveProjectEnumData:
                return "DestructiveProjectEnumData".lowercasedOnlyFirst()
            case .DestructiveInjectEnumTag:
                return "DestructiveInjectEnumTag".lowercasedOnlyFirst()
            case .GetEnumTagSinglePayload:
                return "GetEnumTagSinglePayload".lowercasedOnlyFirst()
            case .StoreEnumTagSinglePayload:
                return "StoreEnumTagSinglePayload".lowercasedOnlyFirst()
            }
        }
    }
}

// MARK: - Debugging
extension Node: CustomDebugStringConvertible {
    
    public var debugDescription: String { printHierarchy() }
    
    public func dump() {
        print(printHierarchy())
    }
    
    // Node와 그 자식들의 kind와 계층 관계를 출력하는 메서드
    func printHierarchy(level: Int = 0) -> String {
        var descriptions: [String] = []
        let prefix = Array<String>(repeating: "\t", count: level).joined()
        
        if payload.hasValue {
            descriptions.append(prefix + "kind=\(kind.rawValue), \(payload)")
        } else {
            descriptions.append(prefix + "kind=\(kind.rawValue)")
        }
        
        if numberOfChildren > 0 {
            for child in copyOfChildren {
                descriptions.append(child.printHierarchy(level: level + 1))
            }
        }
        
        return descriptions.joined(separator: "\n")
    }
}

extension Node.Kind {
    
    private static let declNames: [Node.Kind] = [
        .Identifier,
        .LocalDeclName,
        .PrivateDeclName,
        .RelatedEntityDeclName,
        .PrefixOperator,
        .PostfixOperator,
        .InfixOperator,
        .TypeSymbolicReference,
        .ProtocolSymbolicReference,
        .ObjectiveCProtocolSymbolicReference
    ]
    private static let anyGenerics: [Node.Kind] = [
        .Structure,
        .Class,
        .Enum,
        .Protocol,
        .ProtocolSymbolicReference,
        .ObjectiveCProtocolSymbolicReference,
        .OtherNominalType,
        .TypeAlias,
        .TypeSymbolicReference,
        .BuiltinTupleType
    ]
    private static let requirements: [Node.Kind] = [
        .DependentGenericParamPackMarker,
        .DependentGenericParamValueMarker,
        .DependentGenericSameTypeRequirement,
        .DependentGenericSameShapeRequirement,
        .DependentGenericLayoutRequirement,
        .DependentGenericConformanceRequirement,
        .DependentGenericInverseConformanceRequirement
    ]
    private static let contexts: [Node.Kind] = [
        .Allocator,
        .AnonymousContext,
        .Class,
        .Constructor,
        .Deallocator,
        .DefaultArgumentInitializer,
        .Destructor,
        .DidSet,
        .Enum,
        .ExplicitClosure,
        .Extension,
        .Function,
        .Getter,
        .GlobalGetter,
        .IVarInitializer,
        .IVarDestroyer,
        .ImplicitClosure,
        .Initializer,
        .InitAccessor,
        .IsolatedDeallocator,
        .MaterializeForSet,
        .ModifyAccessor,
        .Modify2Accessor,
        .Module,
        .NativeOwningAddressor,
        .NativeOwningMutableAddressor,
        .NativePinningAddressor,
        .NativePinningMutableAddressor,
        .OtherNominalType,
        .OwningAddressor,
        .OwningMutableAddressor,
        .PropertyWrapperBackingInitializer,
        .PropertyWrapperInitFromProjectedValue,
        .Protocol,
        .ProtocolSymbolicReference,
        .ReadAccessor,
        .Read2Accessor,
        .Setter,
        .Static,
        .Structure,
        .Subscript,
        .TypeSymbolicReference,
        .TypeAlias,
        .UnsafeAddressor,
        .UnsafeMutableAddressor,
        .Variable,
        .WillSet,
        .OpaqueReturnTypeOf,
        .AutoDiffFunction
    ]
    private static let functionAttrs: [Node.Kind] = [
        .FunctionSignatureSpecialization,
        .GenericSpecialization,
        .GenericSpecializationPrespecialized,
        .InlinedGenericFunction,
        .GenericSpecializationNotReAbstracted,
        .GenericPartialSpecialization,
        .GenericPartialSpecializationNotReAbstracted,
        .GenericSpecializationInResilienceDomain,
        .ObjCAttribute,
        .NonObjCAttribute,
        .DynamicAttribute,
        .DirectMethodReferenceAttribute,
        .VTableAttribute,
        .PartialApplyForwarder,
        .PartialApplyObjCForwarder,
        .OutlinedVariable,
        .OutlinedReadOnlyObject,
        .OutlinedBridgedMethod,
        .MergedFunction,
        .DistributedThunk,
        .DistributedAccessor,
        .DynamicallyReplaceableFunctionImpl,
        .DynamicallyReplaceableFunctionKey,
        .DynamicallyReplaceableFunctionVar,
        .AsyncFunctionPointer,
        .AsyncAwaitResumePartialFunction,
        .AsyncSuspendResumePartialFunction,
        .AccessibleFunctionRecord,
        .BackDeploymentThunk,
        .BackDeploymentFallback,
        .HasSymbolQuery,
    ]
    
    var isDeclName: Bool {
        Self.declNames.contains(self)
    }
    
    var isAnyGeneric: Bool {
        Self.anyGenerics.contains(self)
    }
    
    var isEntity: Bool {
        if self == .Type {
            return true
        } else {
            return isContext
        }
    }
    
    var isRequirement: Bool {
        Self.requirements.contains(self)
    }
    
    
    var isContext: Bool {
        Self.contexts.contains(self)
    }
    
    var isFunctionAttr: Bool {
        Self.functionAttrs.contains(self)
    }
    
    var isMacroExpandion: Bool {
        switch self {
        case .AccessorAttachedMacroExpansion,
                .MemberAttributeAttachedMacroExpansion,
                .FreestandingMacroExpansion,
                .MemberAttachedMacroExpansion,
                .PeerAttachedMacroExpansion,
                .ConformanceAttachedMacroExpansion,
                .ExtensionAttachedMacroExpansion,
                .MacroExpansionLoc:
            return true
        default:
            return false
        }
    }
}

extension Optional where Wrapped == Node {
    var isAlias: Bool {
        if let node = self {
            return node.isAlias
        } else {
            return false
        }
    }
    var isClass: Bool {
        if let node = self {
            return node.isClass
        } else {
            return false
        }
    }
    var isEnum: Bool {
        if let node = self {
            return node.isEnum
        } else {
            return false
        }
    }
    var isProtocol: Bool {
        if let node = self {
            return node.isProtocol
        } else {
            return false
        }
    }
    var isStruct: Bool {
        if let node = self {
            return node.isStruct
        } else {
            return false
        }
    }
}
