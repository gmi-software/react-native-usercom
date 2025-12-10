package com.margelo.nitro.usercom

import com.user.sdk.events.Event
import com.user.sdk.events.UserComEvent
import net.bytebuddy.ByteBuddy
import net.bytebuddy.description.annotation.AnnotationDescription
import net.bytebuddy.dynamic.loading.ClassLoadingStrategy
import net.bytebuddy.implementation.MethodDelegation
import net.bytebuddy.implementation.bind.annotation.RuntimeType
import net.bytebuddy.matcher.ElementMatchers


class UserComEventFactory {

    fun createEventClass(
        eventName: String,
        attributes: Map<String, Any>
    ): UserComEvent {

        class ToFlatDelegate(private val data: Map<String, Any>) {
            @RuntimeType
            fun toFlat(): MutableMap<String, Any> {
                return data.toMutableMap()
            }
        }

        val annotation = AnnotationDescription.Builder.ofType(Event::class.java)
            .define("name", eventName)
            .build()

        val generatedClass = ByteBuddy()
            .subclass(UserComEvent::class.java)
            .name("generated.events.${eventName.replace(" ", "_")}")
            .annotateType(annotation)
            .method(ElementMatchers.named("toFlat"))
            .intercept(MethodDelegation.to(ToFlatDelegate(attributes)))
            .make()
            .load(
                this::class.java.classLoader,
                ClassLoadingStrategy.Default.INJECTION
            )
            .loaded

        return generatedClass.getDeclaredConstructor().newInstance()
    }

}